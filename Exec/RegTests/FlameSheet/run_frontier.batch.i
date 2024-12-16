#!/bin/bash
#SBATCH -A VEN113
#SBATCH --job-name=pelelmex
#SBATCH -n%RANKS%                  # number of ranks per node requested
#SBATCH -N%NODES%                  # number of nodes requested
#SBATCH -p batch
#SBATCH --gpus-per-node=%GPN%      # number of APUs per node requested
#SBATCH --hint=nomultithread       # no multithreading
#SBATCH --exclusive                # exclusive allocation of nodes even for partial use
#SBATCH --time=2:00:00             # max time allocation
#SBATCH --threads-per-core=1
#SBATCH --error=frontier_runs_%DATE%/pele_%NODES%.err
#SBATCH --output=frontier_runs_%DATE%/pele_%NODES%.out

gam=%GAM%
size=%SIZE%
max_step=%MAX_STEP%

module reset
module load PrgEnv-cray
module load cpe/24.07
module load craype-x86-trento
module load craype-accel-amd-gfx90a
module load rocm/6.1.3
module list

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

# GPU aware MPI
if [[ $gam -eq 1 ]]; then
    export MPICH_GPU_SUPPORT_ENABLED=1
fi

if [[ $size -eq 1024 ]]; then
    args="inputs.3d.bmt amrex.use_gpu_aware_mpi=$gam amrex.the_arena_is_managed=0 amrex.the_arena_init_size=%ARENA_SIZE% amrex.use_profiler_syncs=0 ode.cfrhs_multi_kernel=%CFRHS_MULTI_KERNEL% ode.cfrhs_min_blocks=%CFRHS_MIN_BLOCKS% amr.max_step=$max_step"
fi
if [[ $size -eq 512 ]]; then
    args="inputs.3d.bmt amr.n_cell=$size $size $size amrex.use_gpu_aware_mpi=$gam amrex.the_arena_is_managed=0 amrex.the_arena_init_size=%ARENA_SIZE% amrex.use_profiler_syncs=0 ode.cfrhs_multi_kernel=%CFRHS_MULTI_KERNEL% ode.cfrhs_min_blocks=%CFRHS_MIN_BLOCKS% amr.max_step=$max_step"
fi
if [[ $size -eq 256 ]]; then
    args="inputs.3d.bmt amr.n_cell=$size $size $size amrex.use_gpu_aware_mpi=$gam amrex.the_arena_is_managed=0 amrex.the_arena_init_size=%ARENA_SIZE% amrex.use_profiler_syncs=0 ode.cfrhs_multi_kernel=%CFRHS_MULTI_KERNEL% ode.cfrhs_min_blocks=%CFRHS_MIN_BLOCKS% amr.max_step=$max_step"
fi

for i in $(seq 1 %NTRIALS%);
do
	 str=NODES_%NODES%_GPN_%GPN%_GAM_${gam}_CFRHS_%CFRHS_MULTI_KERNEL%_%CFRHS_MIN_BLOCKS%_TRIAL_${i}

	 exe=PeleLMeX3d.hip.x86-trento.TPROF.MPI.HIP.ex

	 srun -u -N %NODES% -n %RANKS% --gpu-bind=closest --error=frontier_runs_%DATE%/pelelmex_${str}.err --output=frontier_runs_%DATE%/pelelmex_${str}.out ${exe} ${args}

	 mv condTest000010.dat frontier_runs_%DATE%/condTest000010.dat_${str}
	 mv condTest000020.dat frontier_runs_%DATE%/condTest000020.dat_${str}
done
