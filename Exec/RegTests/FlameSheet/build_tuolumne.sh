#!/bin/bash -l

MYPWD=${PWD}

set -e

export AMD_ARCH=gfx942
module purge
module load cmake/3.29.2
module load PrgEnv-cray
module load craype-x86-genoa
module load craype-accel-amd-gfx942
#module load rocm/6.1.3
export ROCM_PATH=/opt/rocm-6.1.3
export HIP_PATH=/opt/rocm-6.1.3
export PATH=${ROCM_PATH}/bin:$PATH
module list

export MPI_HOME=/opt/cray/pe/mpich/8.1.31/ofi/crayclang/18.0/
export HIP_PLATFORM=amd

make TPLrealclean
make -j4 VERBOSE=1 TPL

make realclean
make -j4 VERBOSE=1
