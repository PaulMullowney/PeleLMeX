#!/bin/bash -l

MYPWD=${PWD}

set -e

export AMD_ARCH=gfx90a
module reset
module load cmake/3.27.9
module load PrgEnv-cray
module load cpe/24.07
module load craype-x86-trento
module load craype-accel-amd-gfx90a
module load rocm/6.1.3
module list

export MPI_HOME=/opt/cray/pe/mpich/8.1.30/ofi/crayclang/17.0/
export HIP_PLATFORM=amd

make TPLrealclean
make -j16 VERBOSE=1 TPL

make realclean
make -j16 VERBOSE=1
