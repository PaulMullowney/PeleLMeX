#!/bin/bash -l

MYPWD=${PWD}

cmd() {
	 echo "+ $@"
	 eval "$@"
}

set -e


cmd "module purge"
cmd "module load PrgEnv-cray"
cmd "module load xpmem"
cmd "module unload cray-libsci"
cmd "module load cray-libsci/22.12.1.1"
cmd "module load craype-x86-rome craype-accel-amd-gfx90a amd/5.4.3"

ARENA_SIZE=$((%MEM%*1024*1024*1024))
#GAM_ARENA_SIZE=$((1024*1024*1024))
EXE=./PeleLMeX3d.hip.x86-rome.TPROF.MPI.HIP.ex.%BUILD%

export MPICH_GPU_SUPPORT_ENABLED=1
#export FI_MR_CACHE_MONITOR=memhooks
#export FI_CXI_RX_MATCH_MODE=software
export MPICH_OFI_NIC_POLICY=GPU
export MPICH_OFI_RMA_STARTUP_CONNECT=1
export MPICH_OFI_STARTUP_CONNECT=1
export ROCFFT_RTC_CACHE_PATH=/dev/null
export MPICH_ALLTOALL_SHORT_MSG=4096
export MPICH_ALLTOALL_SYNC_FREQ=24

srun -u -N%NODES% -n%RANKS% --gpus-per-node=%RANKS% --gpu-bind=closest ${EXE} inputs.3d.bmt amr.n_cell="%SIZEX% %SIZEY% %SIZEZ%" geometry.prob_lo="-0.016 -0.016 -0.016" geometry.prob_hi="0.016 0.016 0.016" amrex.use_gpu_aware_mpi=0 amrex.the_arena_is_managed=0 amrex.the_arena_init_size=${ARENA_SIZE} amrex.use_profiler_syncs=1 amr.max_grid_size=%MGS%  > mgs%MGS%_good_geometry/pelelmex_%NODES%_%RANKS%_%SIZEX%_%SIZEY%_%SIZEZ%.%BUILD%
#  amrex.the_gpuawarempi_arena_init_size=${GAM_ARENA_SIZE}
mv condTest000010.dat mgs%MGS%_good_geometry/condTest000010.dat_%NODES%_%RANKS%_%SIZEX%_%SIZEY%_%SIZEZ%.%BUILD%
mv condTest000020.dat mgs%MGS%_good_geometry/condTest000020.dat_%NODES%_%RANKS%_%SIZEX%_%SIZEY%_%SIZEZ%.%BUILD%
