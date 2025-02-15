#include <PeleLMeX.H>
#include <PeleLMeX_Utils.H>
#include <pelelmex_prob.H>
#include <PeleLMeX_EBUserDefined.H>

#ifdef AMREX_USE_EB
#include <AMReX_EB2.H>
#include <AMReX_EB2_IF.H>
#include <AMReX_EB_Redistribution.H>
#include <AMReX_EBMFInterpolater.H>

using namespace amrex;

void
PeleLM::makeEBGeometry()
{
  BL_PROFILE("PeleLMeX::makeEBGeometry()");
  int max_coarsening_level = 100;
  int req_coarsening_level = static_cast<int>(geom.size()) - 1;

  // Read the geometry type and act accordingly
  ParmParse ppeb2("eb2");
  std::string geom_type;
  ppeb2.get("geom_type", geom_type);

  // At what level should the EB be generated ?
  // Default : max_level
  int prev_max_lvl_eb = max_level;

  // If restarting: use the level at which it was generated earlier
  prev_max_lvl_eb =
    (getRestartEBMaxLevel() > 0) ? getRestartEBMaxLevel() : prev_max_lvl_eb;

  // Manual override if needed -> might incur issues with previously
  // covered/uncovered cell flipping
  ppeb2.query("max_level_generation", prev_max_lvl_eb);
  AMREX_ALWAYS_ASSERT(prev_max_lvl_eb <= max_level);

  // Stash away the level at which we ended up
  m_EB_generate_max_level = prev_max_lvl_eb;

  // Generate the EB data at prev_max_lvl_eb and create consistent coarse
  // version from there.
  if (geom_type == "UserDefined") {
    EBUserDefined(
      geom[prev_max_lvl_eb], req_coarsening_level, max_coarsening_level);
  } else {
    // If geom_type is not an AMReX recognized type, it'll crash.
    EB2::Build(
      geom[prev_max_lvl_eb], req_coarsening_level, max_coarsening_level);
  }

  // Add finer level, might be inconsistent with the coarser level created
  // above.
  EB2::addFineLevels(max_level - prev_max_lvl_eb);
}

void
PeleLM::redistributeAofS(
  int a_lev,
  Real& a_dt,
  MultiFab& a_tmpDiv,
  int div_comp,
  MultiFab& a_AofS,
  int aofs_comp,
  MultiFab& a_state,
  int state_comp,
  int ncomp,
  const BCRec* d_bc,
  const Geometry& a_geom) const
{
  BL_PROFILE("PeleLMeX::redistributeAofS()");
  AMREX_ASSERT(a_tmpDiv.nComp() >= div_comp + ncomp);
  AMREX_ASSERT(a_AofS.nComp() >= aofs_comp + ncomp);
  AMREX_ASSERT(a_state.nComp() >= state_comp + ncomp);

  //----------------------------------------------------------------
  const auto& ebfact = EBFactory(a_lev);

#ifdef AMREX_USE_OMP
#pragma omp parallel if (Gpu::notInLaunchRegion())
#endif
  for (MFIter mfi(a_tmpDiv, TilingIfNotGPU()); mfi.isValid(); ++mfi) {

    Box const& bx = mfi.tilebox();
    auto const& flagfab = ebfact.getMultiEBCellFlagFab()[mfi];
    auto const& flag = flagfab.const_array();
    auto const& divT_ar = a_tmpDiv.array(mfi, div_comp);
    auto const& aofs_ar = a_AofS.array(mfi, aofs_comp);

    if (flagfab.getType(bx) != FabType::covered) {
      if (flagfab.getType(grow(bx, 4)) != FabType::regular) {
        AMREX_D_TERM(auto apx = ebfact.getAreaFrac()[0]->const_array(mfi);
                     , auto apy = ebfact.getAreaFrac()[1]->const_array(mfi);
                     , auto apz = ebfact.getAreaFrac()[2]->const_array(mfi););
        AMREX_D_TERM(
          Array4<Real const> fcx = ebfact.getFaceCent()[0]->const_array(mfi);
          , Array4<Real const> fcy = ebfact.getFaceCent()[1]->const_array(mfi);
          ,
          Array4<Real const> fcz = ebfact.getFaceCent()[2]->const_array(mfi););
        auto const& ccc = ebfact.getCentroid().const_array(mfi);
        auto const& vfrac_arr = ebfact.getVolFrac().const_array(mfi);

        // This is scratch space if calling StateRedistribute,
        // but is used as the weights (here set to 1) if calling
        // FluxRedistribute
        Box gbx = bx;

        if (m_adv_redist_type == "StateRedist") {
          gbx.grow(3);
        } else if (m_adv_redist_type == "FluxRedist") {
          gbx.grow(2);
        }

        FArrayBox tmpfab(gbx, ncomp, The_Async_Arena());
        Array4<Real> scratch = tmpfab.array(0);
        if (m_adv_redist_type == "FluxRedist") {
          amrex::ParallelFor(
            Box(scratch), [=] AMREX_GPU_DEVICE(int i, int j, int k) noexcept {
              scratch(i, j, k) = 1.;
            });
        }
        ApplyRedistribution(
          bx, ncomp, aofs_ar, divT_ar, a_state.const_array(mfi, state_comp),
          scratch, flag, AMREX_D_DECL(apx, apy, apz), vfrac_arr,
          AMREX_D_DECL(fcx, fcy, fcz), ccc, d_bc, a_geom, a_dt,
          m_adv_redist_type);
      } else {
        // Move data to AofS for regular bx
        amrex::ParallelFor(
          bx, ncomp, [=] AMREX_GPU_DEVICE(int i, int j, int k, int n) noexcept {
            aofs_ar(i, j, k, n) = divT_ar(i, j, k, n);
          });
      }
    }
  }
}

void
PeleLM::getCoveredIMask(int a_lev, iMultiFab& a_imask) const
{
  const auto& ebfact = EBFactory(a_lev);
  const auto& flags = ebfact.getMultiEBCellFlagFab();

  if (
    (a_imask.boxArray() == flags.boxArray()) &&
    (a_imask.DistributionMap() == flags.DistributionMap())) {

#ifdef AMREX_USE_OMP
#pragma omp parallel if (Gpu::notInLaunchRegion())
#endif
    for (MFIter mfi(a_imask, TilingIfNotGPU()); mfi.isValid(); ++mfi) {
      const Box& bx = mfi.tilebox();
      const auto& flagarr = flags.const_array(mfi);
      Array4<int> const& arr = a_imask.array(mfi);
      AMREX_HOST_DEVICE_PARALLEL_FOR_3D(bx, i, j, k, {
        if (flagarr(i, j, k).isCovered()) {
          arr(i, j, k) = -1;
        } else {
          arr(i, j, k) = 1;
        }
      });
    }
  } else {

    iMultiFab mask_tmp(flags.boxArray(), flags.DistributionMap(), 1, 0);

#ifdef AMREX_USE_OMP
#pragma omp parallel if (Gpu::notInLaunchRegion())
#endif
    for (MFIter mfi(mask_tmp, TilingIfNotGPU()); mfi.isValid(); ++mfi) {
      const Box& bx = mfi.tilebox();
      const auto& flagarr = flags.const_array(mfi);
      Array4<int> const& arr = mask_tmp.array(mfi);
      AMREX_HOST_DEVICE_PARALLEL_FOR_3D(bx, i, j, k, {
        if (flagarr(i, j, k).isCovered()) {
          arr(i, j, k) = -1;
        } else {
          arr(i, j, k) = 1;
        }
      });
    }
    a_imask.ParallelCopy(mask_tmp, 0, 0, 1);
  }
}

void
PeleLM::redistributeDiff(
  int a_lev,
  const Real& a_dt,
  MultiFab& a_tmpDiv,
  int div_comp,
  MultiFab& a_diff,
  int diff_comp,
  const MultiFab& a_state,
  int state_comp,
  int ncomp,
  const BCRec* d_bc,
  const Geometry& a_geom) const
{
  BL_PROFILE("PeleLMeX::redistributeDiff()");
  AMREX_ASSERT(a_tmpDiv.nComp() >= div_comp + ncomp);
  AMREX_ASSERT(a_diff.nComp() >= diff_comp + ncomp);
  AMREX_ASSERT(a_state.nComp() >= state_comp + ncomp);

  //----------------------------------------------------------------
  const auto& ebfact = EBFactory(a_lev);

#ifdef AMREX_USE_OMP
#pragma omp parallel if (Gpu::notInLaunchRegion())
#endif
  for (MFIter mfi(a_tmpDiv, TilingIfNotGPU()); mfi.isValid(); ++mfi) {

    Box const& bx = mfi.tilebox();
    auto const& flagfab = ebfact.getMultiEBCellFlagFab()[mfi];
    auto const& flag = flagfab.const_array();
    auto const& divT_ar = a_tmpDiv.array(mfi, div_comp);
    auto const& diff_ar = a_diff.array(mfi, diff_comp);

    if (flagfab.getType(bx) != FabType::covered) {
      if (flagfab.getType(grow(bx, 4)) != FabType::regular) {
        AMREX_D_TERM(auto apx = ebfact.getAreaFrac()[0]->const_array(mfi);
                     , auto apy = ebfact.getAreaFrac()[1]->const_array(mfi);
                     , auto apz = ebfact.getAreaFrac()[2]->const_array(mfi););
        AMREX_D_TERM(
          Array4<Real const> fcx = ebfact.getFaceCent()[0]->const_array(mfi);
          , Array4<Real const> fcy = ebfact.getFaceCent()[1]->const_array(mfi);
          ,
          Array4<Real const> fcz = ebfact.getFaceCent()[2]->const_array(mfi););
        auto const& ccc = ebfact.getCentroid().const_array(mfi);
        auto const& vfrac_arr = ebfact.getVolFrac().const_array(mfi);

        // This is scratch space if calling StateRedistribute,
        // but is used as the weights (here set to 1) if calling
        // FluxRedistribute
        Box gbx = bx;

        if (m_diff_redist_type == "StateRedist") {
          gbx.grow(3);
        } else if (m_diff_redist_type == "FluxRedist") {
          gbx.grow(2);
        }

        FArrayBox tmpfab(gbx, ncomp, The_Async_Arena());
        Array4<Real> scratch = tmpfab.array(0);
        if (m_diff_redist_type == "FluxRedist") {
          amrex::ParallelFor(
            Box(scratch), [=] AMREX_GPU_DEVICE(int i, int j, int k) noexcept {
              scratch(i, j, k) = 1.;
            });
        }
        ApplyRedistribution(
          bx, ncomp, diff_ar, divT_ar, a_state.const_array(mfi, state_comp),
          scratch, flag, AMREX_D_DECL(apx, apy, apz), vfrac_arr,
          AMREX_D_DECL(fcx, fcy, fcz), ccc, d_bc, a_geom, a_dt,
          m_diff_redist_type);
      } else {
        // Move data to AofS for regular bx
        amrex::ParallelFor(
          bx, ncomp, [=] AMREX_GPU_DEVICE(int i, int j, int k, int n) noexcept {
            diff_ar(i, j, k, n) = divT_ar(i, j, k, n);
          });
      }
    }
  }
}

void
PeleLM::initCoveredState()
{
  // Zero velocities, typical values on species, 'cold' temperature
  if (m_incompressible != 0) {
    coveredState_h.resize(AMREX_SPACEDIM);
    AMREX_D_TERM(coveredState_h[0] = 0.0;, coveredState_h[1] = 0.0;
                 , coveredState_h[2] = 0.0;)
    coveredState_d.resize(AMREX_SPACEDIM);
    Gpu::copy(
      Gpu::hostToDevice, coveredState_h.begin(), coveredState_h.end(),
      coveredState_d.begin());
  } else {
    coveredState_h.resize(NVAR);
    AMREX_D_TERM(coveredState_h[0] = 0.0;, coveredState_h[1] = 0.0;
                 , coveredState_h[2] = 0.0;)
    coveredState_h[DENSITY] = typical_values[DENSITY];
    for (int n = 0; n < NUM_SPECIES; n++) {
      coveredState_h[FIRSTSPEC + n] = typical_values[FIRSTSPEC + n];
    }
    coveredState_h[RHOH] = typical_values[RHOH];
    coveredState_h[TEMP] = 300.0;
    coveredState_h[RHORT] = typical_values[RHORT];

    coveredState_d.resize(NVAR);
    Gpu::copy(
      Gpu::hostToDevice, coveredState_h.begin(), coveredState_h.end(),
      coveredState_d.begin());
  }
}

void
PeleLM::setCoveredState(const TimeStamp& a_time)
{
  BL_PROFILE("PeleLMeX::setCoveredState()");
  for (int lev = 0; lev <= finest_level; lev++) {
    setCoveredState(lev, a_time);
  }
}

void
PeleLM::setCoveredState(int lev, const TimeStamp& a_time)
{
  AMREX_ASSERT(a_time == AmrOldTime || a_time == AmrNewTime);

  auto* ldata_p = getLevelDataPtr(lev, a_time);

  if (m_incompressible != 0) {
    EB_set_covered(ldata_p->state, 0, AMREX_SPACEDIM, coveredState_h);
  } else {
    EB_set_covered(ldata_p->state, 0, NVAR, coveredState_h);
  }
}

void
PeleLM::initialRedistribution()
{
  // Redistribute the initial solution if adv/diff scheme uses State or NewState
  if (
    m_adv_redist_type == "StateRedist" || m_diff_redist_type == "StateRedist") {

    for (int lev = 0; lev <= finest_level; ++lev) {

      // New time
      Real timeNew = getTime(lev, AmrNewTime);

      // Jungle with Old/New states: fillPatch old and redistribute
      // from Old->New to end up with proper New state
      auto* ldataOld_p = getLevelDataPtr(lev, AmrOldTime);
      auto* ldataNew_p = getLevelDataPtr(lev, AmrNewTime);

      auto const& fact = EBFactory(lev);

      // State
      if (m_incompressible != 0) {
        Vector<Real> stateCovered(AMREX_SPACEDIM, 0.0);
        EB_set_covered(ldataNew_p->state, 0, AMREX_SPACEDIM, stateCovered);
        ldataNew_p->state.FillBoundary(geom[lev].periodicity());
        MultiFab::Copy(
          ldataOld_p->state, ldataNew_p->state, 0, 0, AMREX_SPACEDIM,
          m_nGrowState);
      } else {
        Vector<Real> stateCovered(NVAR, 0.0);
        EB_set_covered(ldataNew_p->state, 0, NVAR, stateCovered);
        ldataNew_p->state.FillBoundary(geom[lev].periodicity());
        MultiFab::Copy(
          ldataOld_p->state, ldataNew_p->state, 0, 0, NVAR, m_nGrowState);
      }
      fillpatch_state(lev, timeNew, ldataOld_p->state, m_nGrowState);

      for (MFIter mfi(ldataNew_p->state, TilingIfNotGPU()); mfi.isValid();
           ++mfi) {

        const Box& bx = mfi.validbox();

        EBCellFlagFab const& flagfab = fact.getMultiEBCellFlagFab()[mfi];
        Array4<EBCellFlag const> const& flag = flagfab.const_array();

        if (
          (flagfab.getType(bx) != FabType::covered) &&
          (flagfab.getType(amrex::grow(bx, 4)) != FabType::regular)) {
          Array4<Real const> AMREX_D_DECL(fcx, fcy, fcz), ccc, vfrac,
            AMREX_D_DECL(apx, apy, apz);
          AMREX_D_TERM(fcx = fact.getFaceCent()[0]->const_array(mfi);
                       , fcy = fact.getFaceCent()[1]->const_array(mfi);
                       , fcz = fact.getFaceCent()[2]->const_array(mfi););
          ccc = fact.getCentroid().const_array(mfi);
          AMREX_D_TERM(apx = fact.getAreaFrac()[0]->const_array(mfi);
                       , apy = fact.getAreaFrac()[1]->const_array(mfi);
                       , apz = fact.getAreaFrac()[2]->const_array(mfi););
          vfrac = fact.getVolFrac().const_array(mfi);

          if (m_incompressible != 0) {
            auto bcRec = fetchBCRecArray(0, AMREX_SPACEDIM);
            auto bcRec_d = convertToDeviceVector(bcRec);
            ApplyInitialRedistribution(
              bx, AMREX_SPACEDIM, ldataNew_p->state.array(mfi, 0),
              ldataOld_p->state.array(mfi, 0), flag,
              AMREX_D_DECL(apx, apy, apz), vfrac, AMREX_D_DECL(fcx, fcy, fcz),
              ccc, bcRec_d.dataPtr(), geom[lev], m_adv_redist_type);
          } else {
            auto bcRec = fetchBCRecArray(0, NVAR);
            auto bcRec_d = convertToDeviceVector(bcRec);
            ApplyInitialRedistribution(
              bx, NVAR, ldataNew_p->state.array(mfi, 0),
              ldataOld_p->state.array(mfi, 0), flag,
              AMREX_D_DECL(apx, apy, apz), vfrac, AMREX_D_DECL(fcx, fcy, fcz),
              ccc, bcRec_d.dataPtr(), geom[lev], m_adv_redist_type);
          }
        }
      }
    }
  }

  // Initialize covered state
  setCoveredState(AmrNewTime);
}

void
PeleLM::getEBDistance(int a_lev, MultiFab& a_signDistLev)
{

  BL_PROFILE("PeleLMeX::getEBDistance()");

  if (a_lev == 0) {
    MultiFab::Copy(a_signDistLev, *m_signedDist0, 0, 0, 1, 0);
    return;
  }

  // A pair of MF to hold crse & fine dist data
  Array<std::unique_ptr<MultiFab>, 2> MFpair;

  // Interpolate on successive levels up to a_lev
  for (int lev = 1; lev <= a_lev; ++lev) {

    // Use MF EB interp
    auto& interpolater = eb_mf_lincc_interp;

    // Get signDist on coarsen fineBA
    BoxArray coarsenBA(grids[lev].size());
    for (int j = 0, N = static_cast<int>(coarsenBA.size()); j < N; ++j) {
      coarsenBA.set(
        j, interpolater.CoarseBox(grids[lev][j], refRatio(lev - 1)));
    }
    MultiFab coarsenSignDist(coarsenBA, dmap[lev], 1, 0);
    coarsenSignDist.setVal(0.0);
    MultiFab* crseSignDist = (lev == 1) ? m_signedDist0.get() : MFpair[0].get();
    coarsenSignDist.ParallelCopy(*crseSignDist, 0, 0, 1);

    // Interpolate on current lev
    MultiFab* currentSignDist;
    if (lev < a_lev) {
      MFpair[1] = std::make_unique<MultiFab>(
        grids[lev], dmap[lev], 1, 0, MFInfo(), EBFactory(lev));
    }
    currentSignDist = (lev == a_lev) ? &a_signDistLev : MFpair[1].get();

    interpolater.interp(
      coarsenSignDist, 0, *currentSignDist, 0, 1, IntVect(0), Geom(lev - 1),
      Geom(lev), Geom(lev).Domain(), refRatio(lev - 1), {m_bcrec_force}, 0);

    // Swap MFpair
    if (lev < a_lev) {
      swap(MFpair[0], MFpair[1]);
    }
  }
}

void
PeleLM::getEBState(
  int a_lev, const Real& a_time, MultiFab& a_EBstate, int stateComp, int nComp)
{
  AMREX_ASSERT(a_EBstate.nComp() >= nComp);

  // Get Geom / EB data
  ProbParm const* lprobparm = prob_parm_d;
  const auto geomdata = geom[a_lev].data();
  const auto& ebfact = EBFactory(a_lev);
  Array<const MultiCutFab*, AMREX_SPACEDIM> faceCentroid = ebfact.getFaceCent();

  MFItInfo mfi_info;
  if (Gpu::notInLaunchRegion()) {
    mfi_info.EnableTiling().SetDynamic(true);
  }

#ifdef AMREX_USE_OMP
#pragma omp parallel if (Gpu::notInLaunchRegion())
#endif
  for (MFIter mfi(a_EBstate, mfi_info); mfi.isValid(); ++mfi) {
    const Box& bx = mfi.tilebox();
    auto const& flagfab = ebfact.getMultiEBCellFlagFab()[mfi];
    auto const& flag = flagfab.const_array();
    const auto& ebState = a_EBstate.array(mfi);

    if (flagfab.getType(bx) == FabType::covered) { // Set to zero
      AMREX_PARALLEL_FOR_4D(
        bx, nComp, i, j, k, n, { ebState(i, j, k, n) = 0.0; });
    } else if (flagfab.getType(bx) == FabType::regular) { // Set to zero
      AMREX_PARALLEL_FOR_4D(
        bx, nComp, i, j, k, n, { ebState(i, j, k, n) = 0.0; });
    } else {
      AMREX_D_TERM(const auto& ebfc_x = faceCentroid[0]->array(mfi);
                   , const auto& ebfc_y = faceCentroid[1]->array(mfi);
                   , const auto& ebfc_z = faceCentroid[2]->array(mfi););
      amrex::ParallelFor(
        bx, [=] AMREX_GPU_DEVICE(int i, int j, int k) noexcept {
          // Regular/covered cells -> 0.0
          if (flag(i, j, k).isCovered() || flag(i, j, k).isRegular()) {
            for (int n = 0; n < nComp; n++) {
              ebState(i, j, k, n) = 0.0;
            }
          } else { // cut-cells
            // Get the EBface centroid coordinates
            const amrex::Real* dx = geomdata.CellSize();
            const amrex::Real* prob_lo = geomdata.ProbLo();
            const amrex::Real xcell[AMREX_SPACEDIM] = {AMREX_D_DECL(
              prob_lo[0] + (i + 0.5) * dx[0], prob_lo[1] + (j + 0.5) * dx[1],
              prob_lo[2] + (k + 0.5) * dx[2])};
            const amrex::Real xface[AMREX_SPACEDIM] = {AMREX_D_DECL(
              xcell[0] + ebfc_x(i, j, k) * dx[0],
              xcell[1] + ebfc_y(i, j, k) * dx[1],
              xcell[2] + ebfc_z(i, j, k) * dx[2])};

            // TODO : would be practical to have the current state at the EBface
            // ...
            amrex::Real stateExt[NVAR] = {0.0};

            // User-defined fill function
            setEBState(xface, stateExt, a_time, geomdata, *lprobparm);

            // Extract requested entries
            for (int n = 0; n < nComp; n++) {
              ebState(i, j, k, n) = stateExt[stateComp + n];
            }
          }
        });
    }
  }
}

void
PeleLM::getEBDiff(
  int a_lev, const TimeStamp& a_time, MultiFab& a_EBDiff, int diffComp)
{
  // Get Geom / EB data
  ProbParm const* lprobparm = prob_parm_d;
  const auto geomdata = geom[a_lev].data();
  const auto& ebfact = EBFactory(a_lev);
  Array<const MultiCutFab*, AMREX_SPACEDIM> faceCentroid = ebfact.getFaceCent();

  // Get diffusivity cell-centered
  auto* ldata_p = getLevelDataPtr(a_lev, a_time);

  MFItInfo mfi_info;
  if (Gpu::notInLaunchRegion()) {
    mfi_info.EnableTiling().SetDynamic(true);
  }

#ifdef AMREX_USE_OMP
#pragma omp parallel if (Gpu::notInLaunchRegion())
#endif
  for (MFIter mfi(a_EBDiff, mfi_info); mfi.isValid(); ++mfi) {
    const Box& bx = mfi.tilebox();
    auto const& flagfab = ebfact.getMultiEBCellFlagFab()[mfi];
    auto const& flag = flagfab.const_array();
    const auto& ebdiff = a_EBDiff.array(mfi);
    const auto& diff_cc = ldata_p->diff_cc.const_array(mfi, diffComp);

    if (flagfab.getType(bx) == FabType::covered) { // Set to zero
      AMREX_PARALLEL_FOR_3D(bx, i, j, k, { ebdiff(i, j, k) = 0.0; });
    } else if (flagfab.getType(bx) == FabType::regular) { // Set to zero
      AMREX_PARALLEL_FOR_3D(bx, i, j, k, { ebdiff(i, j, k) = 0.0; });
    } else {
      AMREX_D_TERM(const auto& ebfc_x = faceCentroid[0]->array(mfi);
                   , const auto& ebfc_y = faceCentroid[1]->array(mfi);
                   , const auto& ebfc_z = faceCentroid[2]->array(mfi););
      amrex::ParallelFor(
        bx, [=] AMREX_GPU_DEVICE(int i, int j, int k) noexcept {
          // Regular/covered cells -> 0.0
          if (flag(i, j, k).isCovered() || flag(i, j, k).isRegular()) {
            ebdiff(i, j, k) = 0.0;
          } else { // cut-cells
            // Get the EBface centroid coordinates
            const amrex::Real* dx = geomdata.CellSize();
            const amrex::Real* prob_lo = geomdata.ProbLo();
            const amrex::Real xcell[AMREX_SPACEDIM] = {AMREX_D_DECL(
              prob_lo[0] + (i + 0.5) * dx[0], prob_lo[1] + (j + 0.5) * dx[1],
              prob_lo[2] + (k + 0.5) * dx[2])};
            const amrex::Real xface[AMREX_SPACEDIM] = {AMREX_D_DECL(
              xcell[0] + ebfc_x(i, j, k) * dx[0],
              xcell[1] + ebfc_y(i, j, k) * dx[1],
              xcell[2] + ebfc_z(i, j, k) * dx[2])};
            amrex::Real ebflagtype = 0.0;
            setEBType(xface, ebflagtype, geomdata, *lprobparm);
            ebdiff(i, j, k) = diff_cc(i, j, k) * ebflagtype;
          }
        });
    }
  }
}

void
PeleLM::correct_vel_small_cells(
  Vector<MultiFab*> const& a_vel,
  Vector<Array<MultiFab const*, AMREX_SPACEDIM>> const& a_umac)
{
  BL_PROFILE("PeleLMeX::correct_vel_small_cells");

  for (int lev = 0; lev <= finest_level; lev++) {
#ifdef AMREX_USE_OMP
#pragma omp parallel if (Gpu::notInLaunchRegion())
#endif
    for (MFIter mfi(*a_vel[lev], TilingIfNotGPU()); mfi.isValid(); ++mfi) {
      // Tilebox
      const Box bx = mfi.tilebox();

      EBCellFlagFab const& flags = EBFactory(lev).getMultiEBCellFlagFab()[mfi];

      // Face-centered velocity components
      AMREX_D_TERM(const auto& umac_fab = (a_umac[lev][0])->const_array(mfi);
                   , const auto& vmac_fab = (a_umac[lev][1])->const_array(mfi);
                   ,
                   const auto& wmac_fab = (a_umac[lev][2])->const_array(mfi););

      // No cut cells in this FAB
      if (
        (flags.getType(amrex::grow(bx, 0)) == FabType::covered) ||
        (flags.getType(amrex::grow(bx, 1)) == FabType::regular)) {
        // do nothing
      } else { // Cut cells in this FAB
        // Face-centered areas
        AMREX_D_TERM(const auto& apx_fab =
                       EBFactory(lev).getAreaFrac()[0]->const_array(mfi);
                     , const auto& apy_fab =
                         EBFactory(lev).getAreaFrac()[1]->const_array(mfi);
                     , const auto& apz_fab =
                         EBFactory(lev).getAreaFrac()[2]->const_array(mfi););

        const auto& vfrac_fab = EBFactory(lev).getVolFrac().const_array(mfi);

        const auto& ccvel_fab = a_vel[lev]->array(mfi);

        // This FAB has cut cells -- we define the centroid value in terms of
        // the MAC velocities onfaces
        amrex::ParallelFor(
          bx, [vfrac_fab, AMREX_D_DECL(apx_fab, apy_fab, apz_fab), ccvel_fab,
               AMREX_D_DECL(
                 umac_fab, vmac_fab,
                 wmac_fab)] AMREX_GPU_DEVICE(int i, int j, int k) noexcept {
            if (vfrac_fab(i, j, k) > 0.0 && vfrac_fab(i, j, k) < 5.e-3) {
              AMREX_D_TERM(
                Real u_avg = (apx_fab(i, j, k) * umac_fab(i, j, k) +
                              apx_fab(i + 1, j, k) * umac_fab(i + 1, j, k)) /
                             (apx_fab(i, j, k) + apx_fab(i + 1, j, k));
                , Real v_avg = (apy_fab(i, j, k) * vmac_fab(i, j, k) +
                                apy_fab(i, j + 1, k) * vmac_fab(i, j + 1, k)) /
                               (apy_fab(i, j, k) + apy_fab(i, j + 1, k));
                , Real w_avg = (apz_fab(i, j, k) * wmac_fab(i, j, k) +
                                apz_fab(i, j, k + 1) * wmac_fab(i, j, k + 1)) /
                               (apz_fab(i, j, k) + apz_fab(i, j, k + 1)););

              AMREX_D_TERM(ccvel_fab(i, j, k, 0) = u_avg;
                           , ccvel_fab(i, j, k, 1) = v_avg;
                           , ccvel_fab(i, j, k, 2) = w_avg;);
            }
          });
      }
    }
  }
}

int
PeleLM::getRestartEBMaxLevel() const
{
  if (m_restart_chkfile.empty()) {
    return -1;
  }
  // Go and parse the line we need
  std::string File(m_restart_chkfile + "/Header");

  VisMF::IO_Buffer io_buffer(VisMF::GetIOBufferSize());

  Vector<char> fileCharPtr;
  ParallelDescriptor::ReadAndBcastFile(File, fileCharPtr);
  std::string fileCharPtrString(fileCharPtr.dataPtr());
  std::istringstream is(fileCharPtrString, std::istringstream::in);

  std::string line;

  // Title line
  std::getline(is, line);

  // Finest level
  std::getline(is, line);

  // Step count
  std::getline(is, line);

  // Either what we're looking for or m_cur_time
  std::getline(is, line);

  if (line.find('.') != std::string::npos) {
    return -1;
  }
  int max_eb_rst = -1;
  max_eb_rst = std::stoi(line);
  return max_eb_rst;
}
#endif
