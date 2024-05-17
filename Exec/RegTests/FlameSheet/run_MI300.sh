#!/bin/bash -l

model=LiDryer
ranks=1
cfrhs_multi_kernel=0
cfrhs_min_blocks=2
nompi=NO

for i in "$@"; do
    case "$1" in
        -model=*|--model=*)
            model="${i#*=}"
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
        -ranks=*|--ranks=*)
            ranks="${i#*=}"
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
        -with-mpi=*|--with-mpi=*)
	    mpi="${i#*=}"
	    shift # past argument=value
	    ;;
        -without-mpi|--without-mpi)
	    nompi=YES
	    shift # past argument=value
	    ;;
	-fast|--fast)
            fast=YES
            shift # past argument=value
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ $nompi == "YES" ];
then
    # explicitly disable MPI
    echo "Running without MPI with 1 rank"
    ranks=1
    
elif [ -z ${mpi+x} ]; #check if value is passed as an arg
then
    #attempt to read any ompi version in /opt
    mpi=$(readlink -f /opt/omp*)
    if test -d $mpi; then
	export PATH=$mpi/bin/:$PATH
    else
	echo "Could NOT find MPI Path. Exiting"
	exit 1
    fi
else
    if test -d $mpi/; #check value of passed argument
    then
	export PATH=$mpi/bin/:$PATH
    else
	echo "MPI arg not a real path. Exiting"
	exit 1
    fi
fi

echo $model, $ranks

#  pelec.init_shrink=1.0 pelec.change_max=1.0 
if [[ $max_step ]]
then
    MAX_STEP=$max_step
else
    MAX_STEP=20
fi
if [[ $arena_size ]]
then
    ARENA_SIZE=$arena_size
else
    ARENA_SIZE=96000000000
fi


ARGS="inputs.3d.bmt amr.n_cell=192 192 192 geometry.prob_lo=-0.016 -0.016 -0.016 geometry.prob_hi=0.016 0.016 0.016 amrex.use_gpu_aware_mpi=0 amrex.the_arena_is_managed=0 amrex.the_arena_init_size=$ARENA_SIZE amrex.use_profiler_syncs=0 amr.max_grid_size=64 ode.cfrhs_multi_kernel=$cfrhs_multi_kernel ode.cfrhs_min_blocks=$cfrhs_min_blocks amr.max_step=$MAX_STEP" # ode.atomic_reductions=0"

if [ $nompi == "YES" ];
then
    PeleLMeX3d.hip.TPROF.HIP.ex.$model ${ARGS}
else
    mpirun -n $ranks PeleLMeX3d.hip.TPROF.MPI.HIP.ex.$model ${ARGS}
fi

