#!/bin/bash -l

MYPWD=${PWD}

cmd() {
	 echo "+ $@"
	 eval "$@"
}

set -e


cmd "module purge"
cmd "module load PrgEnv-gnu"
cmd "module load xpmem"
cmd "module unload cray-libsci"
cmd "module load cray-libsci/22.12.1.1"
cmd "module load craype-x86-rome"

ARENA_SIZE=17179869184
EXE=./PeleLMeX3d.gnu.x86-rome.TPROF.MPI.OMP.ex
export OMP_NUM_THREADS=8
srun -u -N%NODES% -n%RANKS% ${EXE} inputs.3d.bmt amr.n_cell="%SIZE% %SIZE% %SIZE%" geometry.prob_lo="-0.016 -0.016 -0.016" geometry.prob_hi="0.016 0.016 0.016" amrex.use_gpu_aware_mpi=0 amrex.the_arena_is_managed=0 amrex.the_arena_init_size=${ARENA_SIZE} amrex.use_profiler_syncs=1 amr.max_grid_size=%MGS% amr.blocking_factor=16 > mgs%MGS%_good_geometry/pelelmex_%NODES%_%RANKS%_%SIZE%.%BUILD%
#mv condTest000010.dat mgs%MGS%_good_geometry/condTest000010.dat_%NODES%_%RANKS%_%SIZE%.%BUILD%
#mv condTest000020.dat mgs%MGS%_good_geometry/condTest000020.dat_%NODES%_%RANKS%_%SIZE%.%BUILD%
#geometry.prob_lo="-0.016 -0.016 -0.016" geometry.prob_hi="0.016 0.016 0.016" 
