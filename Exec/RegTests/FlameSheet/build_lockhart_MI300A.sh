#!/bin/bash -l

MYPWD=${PWD}

set -e

export AMD_ARCH=gfx942
module purge
module load cmake/3.28.3
module load PrgEnv-cray
module load craype-x86-genoa
module load craype-accel-amd-gfx942
#module load amd/6.1.1
#module unload rocm/6.1.1
export ROCM_PATH=/opt/COE_modules/rocm/rocm-6.1.3
export HIP_PATH=/opt/COE_modules/rocm/rocm-6.1.3
export PATH=${ROCM_PATH}/bin:$PATH
module list
export MPI_HOME=/opt/cray/pe/mpich/8.1.29/ofi/crayclang/17.0/
export HIP_PLATFORM=amd

make TPLrealclean
make -j32 VERBOSE=1 TPL

make realclean
make -j1 VERBOSE=1
