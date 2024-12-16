#!/bin/bash -l
defrag=%DEFRAG%
thp=%THP%
gam=%GAM%
size=%SIZE%
rprof=%RPROF%
max_step=%MAX_STEP%

date=$(date '+%Y-%m-%d')
odir=tuolumne_runs_${date}
if [[ ! -d ${odir} ]]; then
    echo "Making directory"
    mkdir -p ${odir}
fi


module purge
module load PrgEnv-cray
module load craype-x86-genoa
module load craype-accel-amd-gfx942
#module load rocm/6.1.3
export ROCM_PATH=/opt/rocm-6.1.3
export HIP_PATH=/opt/rocm-6.1.3
export PATH=${ROCM_PATH}/bin:$PATH
module list

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CRAY_LD_LIBRARY_PATH}

ldd PeleLMeX3d.hip.x86-genoa.TPROF.MPI.HIP.ex

# GPU aware MPI
if [[ $gam -eq 1 ]]; then
    export MPICH_GPU_SUPPORT_ENABLED=1		
fi

#geometry.prob_lo=-0.064 -0.064 -0.064 geometry.prob_hi=0.064 0.064 0.064 
if [[ $size -eq 1024 ]]; then
    args="inputs.3d.bmt amrex.use_gpu_aware_mpi=$gam amrex.the_arena_is_managed=0 amrex.the_arena_init_size=%ARENA_SIZE% amrex.use_profiler_syncs=0 ode.cfrhs_multi_kernel=%CFRHS_MULTI_KERNEL% ode.cfrhs_min_blocks=%CFRHS_MIN_BLOCKS% amr.max_step=$max_step"
fi
if [[ $size -eq 512 ]]; then
    args="inputs.3d.bmt amr.n_cell=$size $size $size amrex.use_gpu_aware_mpi=$gam amrex.the_arena_is_managed=0 amrex.the_arena_init_size=%ARENA_SIZE% amrex.use_profiler_syncs=0 ode.cfrhs_multi_kernel=%CFRHS_MULTI_KERNEL% ode.cfrhs_min_blocks=%CFRHS_MIN_BLOCKS% amr.max_step=$max_step"
fi
if [[ $size -eq 256 ]]; then
    args="inputs.3d.bmt amr.n_cell=$size $size $size amrex.use_gpu_aware_mpi=$gam amrex.the_arena_is_managed=0 amrex.the_arena_init_size=%ARENA_SIZE% amrex.use_profiler_syncs=0 ode.cfrhs_multi_kernel=%CFRHS_MULTI_KERNEL% ode.cfrhs_min_blocks=%CFRHS_MIN_BLOCKS% amr.max_step=$max_step"
fi

export OMP_NUM_THREADS=1
#export CRAY_OMP_CHECK_AFFINITY=TRUE
export MPIBIND_RESTRICT=1-7,9-15,17-23,25-31,33-39,41-47,49-55,57-63,65-71,73-79,81-87,89-95,97-103,105-111,113-119,121-127,129-135,137-143,145-151,153-159,161-167,169-175,177-183,185-191

if [[ $rprof -eq 1 ]]; then
    CMD=./rprof_tuolumne.sh
else
    CMD=./start_tuolumne.sh
fi

ntrials=%NTRIALS%
first_trial=1
last_trial=$((first_trial+ntrials-1))
for i in $(seq ${first_trial} ${last_trial});
do
    str=NODES_%NODES%_GPN_%GPN%_GAM_${gam}_XNACK_%XNACK%_THP_${thp}_DEFRAG_${defrag}_CFRHS_%CFRHS_MULTI_KERNEL%_%CFRHS_MIN_BLOCKS%_TRIAL_${i}
    
    if [[ $defrag -eq 1 ]]; then
	sh run_defrag_v3.sh
    fi

    error_file=${odir}/pelelmex_${str}.err
    output_file=${odir}/pelelmex_${str}.out

    if [[ $thp -eq 1 ]]; then
	module load craype-hugepages2M
	ODIR=${odir} STR=${str} ARGS=${args} flux run -x -u  --env=HSA_XNACK=%XNACK% -t 5m -N %NODES% --tasks-per-node %GPN% --gpus-per-node %GPN% -o mpibind=on,verbose -o userrc=/collab/usr/global/tools/spindle/toss_4_x86_64_ib_cray/etc/spindle/spindle.rc -o spindle --error=${error_file} --output=${output_file} --setattr=thp=always ${CMD}
    else
	ODIR=${odir} STR=${str} ARGS=${args} flux run -x -u  --env=HSA_XNACK=%XNACK% -t 5m -N %NODES% --tasks-per-node %GPN% --gpus-per-node %GPN% -o mpibind=on,verbose -o userrc=/collab/usr/global/tools/spindle/toss_4_x86_64_ib_cray/etc/spindle/spindle.rc -o spindle --error=${error_file} --output=${output_file} ${CMD}
    fi

    mv condTest000010.dat ${odir}/condTest000010.dat_${str}
    mv condTest000020.dat ${odir}/condTest000020.dat_${str}
done
