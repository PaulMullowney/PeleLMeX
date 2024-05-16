#!/bin/bash -l

MYPWD=${PWD}

set -e

export AMD_ARCH=gfx90a
module purge
module load cmake/3.28.3
module load PrgEnv-cray
module load xpmem
module unload cray-libsci
module load cray-libsci/22.10.1.2
module load craype-x86-rome craype-accel-amd-gfx90a rocm/5.7.3


module list

export MPI_HOME=/opt/cray/pe/mpich/8.1.28/ofi/crayclang/17.0/
export HIP_PLATFORM=amd

#make TPLrealclean
#make -j32 VERBOSE=1 TPL

#make realclean
make -j32 VERBOSE=1
