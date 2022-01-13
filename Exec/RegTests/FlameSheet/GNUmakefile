TOP = ../../../..
SUBMODS = $(PWD)/../../../Submodules
AMREX_HOME         ?= ${SUBMODS}/amrex
PELELMEX_HOME      ?= ${TOP}/PeleLMeX
PELE_PHYSICS_HOME  ?= ${SUBMODS}/PelePhysics
AMREX_HYDRO_HOME   ?= ${SUBMODS}/AMReX-Hydro


# AMReX
DIM             = 3
DEBUG           = FALSE
PRECISION       = DOUBLE
VERBOSE         = FALSE
TINY_PROFILE    = TRUE

# Compilation
COMP            = clang
USE_MPI         = TRUE
USE_OMP         = FALSE
USE_CUDA        = FALSE
USE_HIP         = TRUE

# PeleLMeX
USE_EFIELD      = FALSE
PELE_USE_MAGMA  = TRUE

# PelePhysics
Chemistry_Model = dodecane_lu
Eos_Model       = Fuego
Transport_Model = Simple

include $(PELELMEX_HOME)/Utils/Make.PeleLMeX

includes += -I${ROCM_PATH}/include
FINAL_LIBS += -L${ROCM_PATH}/lib -lamdhip64
