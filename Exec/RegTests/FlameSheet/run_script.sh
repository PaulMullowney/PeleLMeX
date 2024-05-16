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

ARENA_SIZE=17179869184
EXE=./PeleLMeX3d.hip.x86-rome.TPROF.MPI.HIP.ex.opt

srun -u -N1 -n1 --gpus-per-node=1 --gpu-bind=closest ${EXE} inputs.3d.bmt amr.n_cell="128 128 128" geometry.prob_lo="-0.016 -0.016 -0.016" geometry.prob_hi="0.016 0.016 0.016" amrex.use_gpu_aware_mpi=0 amrex.the_arena_is_managed=0 amrex.the_arena_init_size=${ARENA_SIZE} amrex.use_profiler_syncs=1 amr.max_grid_size=64 > mgs64_good_geometry/pelelmex_1_1_128.opt
mv condTest000010.dat mgs64_good_geometry/condTest000010.dat_1_1_128.opt
mv condTest000020.dat mgs64_good_geometry/condTest000020.dat_1_1_128.opt
#geometry.prob_lo="-0.016 -0.016 -0.016" geometry.prob_hi="0.016 0.016 0.016" 
