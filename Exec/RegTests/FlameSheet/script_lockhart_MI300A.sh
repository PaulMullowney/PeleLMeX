#!/bin/bash -l

ranks=1
cfrhs_multi_kernel=0
cfrhs_min_blocks=1
gam=0
xnack=0
thp=0
defrag=0
max_step=20
arena_size=64000000000
rprof=0
for i in "$@"; do
    case "$1" in
        -ranks=*|--ranks=*)
            ranks="${i#*=}"
            shift # past argument=value
            ;;
        -arena_size=*|--arena_size=*)
            arena_size="${i#*=}"
            shift # past argument=value
            ;;
        -max_step=*|--max_step=*)
            max_step="${i#*=}"
            shift # past argument=value
            ;;
        -cfrhs_multi_kernel=*|--cfrhs_multi_kernel=*)
            cfrhs_multi_kernel="${i#*=}"
            shift # past argument=value
            ;;
        -cfrhs_min_blocks=*|--cfrhs_min_blocks=*)
            cfrhs_min_blocks="${i#*=}"
            shift # past argument=value
            ;;
        -size=*|--size=*)
            size="${i#*=}"
            shift # past argument=value
            ;;
	-gam|--gam)
            gam=1
            shift # past argument=value
            ;;
	-rprof|--rprof)
            rprof=1
            shift # past argument=value
            ;;
	-xnack|--xnack)
            xnack=1
            shift # past argument=value
            ;;
	-defrag|--defrag)
            defrag=1
            shift # past argument=value
            ;;
	-thp|--thp)
            thp=1
            shift # past argument=value
            ;;
        --)
            shift
            break
            ;;
    esac
done

module purge
module load cmake/3.28.3
module load PrgEnv-cray
module load craype-x86-genoa
module load craype-accel-amd-gfx942
#module unload rocm/6.1.1
export ROCM_PATH=/opt/COE_modules/rocm/rocm-6.1.3
export HIP_PATH=/opt/COE_modules/rocm/rocm-6.1.3

# GPU aware MPI
if [[ $gam -eq 1 ]]; then
    export MPICH_GPU_SUPPORT_ENABLED=1		
    export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}
fi

if [[ $defrag -eq 1 ]]; then
    srun_opts="-u --nodes=1 --ntasks-per-node=1"
    output_opts="--output=defragMI300A.stdout --error=defragMI300A.stderr"
    defragEXE=${PWD}/defragMI300A_v3
    srun $srun_opts $output_opts $defragEXE
fi

args="inputs.3d.bmt amr.n_cell=$size $size $size geometry.prob_lo=-0.016 -0.016 -0.016 geometry.prob_hi=0.016 0.016 0.016 amrex.use_gpu_aware_mpi=$gam amrex.the_arena_is_managed=0 amrex.the_arena_init_size=$arena_size amrex.use_profiler_syncs=0 amr.max_grid_size=64 ode.cfrhs_multi_kernel=$cfrhs_multi_kernel ode.cfrhs_min_blocks=$cfrhs_min_blocks amr.max_step=$max_step peleLM.num_init_iter=3" # ode.atomic_reductions=0"

#./affinity_MI300A.sh 
ROCPROF=$rprof ARGS=${args} HSA_XNACK=${xnack} THP=${thp} srun -n $ranks ./start_MI300A.sh
