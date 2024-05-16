#!/bin/bash -l

MYPWD=${PWD}

cmd() {
	 echo "+ $@"
	 eval "$@"
}

set -e

export PATH=/home/pmullown/software/bin/:$PATH
cmd "which cmake"
cmd "cmake --version"
cmd "module purge"
cmd "module load PrgEnv-gnu"
cmd "module load xpmem"
cmd "module unload cray-libsci"
cmd "module load cray-libsci/22.10.1.2"
cmd "module load craype-x86-rome"

cmd "make TPLrealclean"
cmd "make -j1 VERBOSE=1 TPL"

cmd "make realclean"
cmd "make -j1 VERBOSE=1"
