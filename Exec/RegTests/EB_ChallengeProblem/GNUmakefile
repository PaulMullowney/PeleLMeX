TOP = ../../../..
AMREX_HOME         ?= ${TOP}/amrex
PELELMEX_HOME      ?= ${TOP}/PeleLMeX
PELE_PHYSICS_HOME  ?= ${TOP}/PelePhysics
AMREX_HYDRO_HOME   ?= ${TOP}/AMReX-Hydro
HYPRE_HOME         = /gpfs/alpine/cmb138/scratch/mullowne/install/gpu/hypre-IterTriSolve-2022-01-24/

# AMReX
DIM             = 3
DEBUG           = FALSE
PRECISION       = DOUBLE
VERBOSE         = FALSE
TINY_PROFILE    = FALSE
USE_EB          = TRUE
USE_HYPRE       = TRUE

# Compilation
COMP            = gcc
USE_MPI         = TRUE
USE_OMP         = FALSE
USE_CUDA        = TRUE
USE_HIP         = FALSE

# PeleLMeX
CEXE_headers 	+= EBUserDefined.H

# PelePhysics
Chemistry_Model = air
Eos_Model = Fuego
Transport_Model = Constant

include $(PELELMEX_HOME)/Utils/Make.PeleLMeX
