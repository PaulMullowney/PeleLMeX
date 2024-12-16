# AMReX
DIM = 3
COMP = gnu
PRECISION = DOUBLE
USE_EB = FALSE
USE_HYPRE = FALSE

# Profiling
PROFILE = FALSE
TINY_PROFILE = TRUE
COMM_PROFILE = FALSE
TRACE_PROFILE = FALSE
MEM_PROFILE = FALSE
USE_GPROF = FALSE

# Performance
USE_MPI = TRUE
USE_OMP = FALSE
USE_CUDA = FALSE
USE_HIP = TRUE
USE_SYCL = FALSE
USE_ROCTX = TRUE
USE_GPU_RDC = FALSE
USE_HYPRE = FALSE
#HYPRE_HOME=/p/lustre5/mullowney1/software/rocm-6.1.3/hypre
#UMPIRE_HOME=/p/lustre5/mullowney1/software/rocm-6.1.3/Umpire

# Debugging
DEBUG = FALSE
FSANITIZER = FALSE
THREAD_SANITIZER = FALSE

# PeleLMeX
USE_EFIELD = FALSE
PELE_COMPILE_AJACOBIAN = FALSE
PELE_USE_MAGMA  = FALSE

# PelePhysics
USE_MANIFOLD = FALSE
ifeq ($(USE_MANIFOLD), TRUE)
  Eos_Model       = Manifold
  Chemistry_Model = Null
  Transport_Model = Manifold
  Manifold_Dim = 1
 # Manifold_Type = Table
else
  Chemistry_Model = drm19
  Eos_Model = Fuego
  Transport_Model = Simple
endif

PELE_HOME ?= ../../..
include $(PELE_HOME)/Exec/Make.PeleLMeX
