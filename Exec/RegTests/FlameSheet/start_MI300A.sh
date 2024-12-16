#!/bin/bash

APU_LIST=(0 1 2 3)                  # APU index list
#let NUM_GPUS=${SLURM_GPUS_PER_NODE} # Number of APUs requested
#let GPU_START=0
#let GPU_STRIDE=1
#let MY_RANK=${SLURM_LOCALID}

#tasks_per_node=$((SLURM_NPROCS/SLURM_JOB_NUM_NODES))
#let ranks_per_gpu=$(((${tasks_per_node}+${NUM_GPUS}-1)/${NUM_GPUS}))
#let my_gpu=$(($MY_RANK*$GPU_STRIDE/$ranks_per_gpu))+${GPU_START}

#export ROCR_VISIBLE_DEVICES=${APU_LIST[$my_gpu]}
export ROCR_VISIBLE_DEVICES=${APU_LIST[$SLURM_LOCALID]}

if [[ $MEMORY_PROFILE -eq 1 ]]; then
    NSAMPLES=400
    device=$ROCR_VISIBLE_DEVICES
    memory_outfile="./memory_usage_device_${device}.txt"
    eval "rocm-smi --showmemuse $*"
    for i in $(seq 1 $NSAMPLES); do
	current_time=$(date +"%T.%3N")
	echo "Sample=$i $current_time" >> $memory_outfile
	rocm-smi --device $device --showmemuse >> $memory_outfile
    done &  # Run memory loop in background
fi

# Set huge pages
if [[ $THP -eq 1 ]]; then
    sudo cat /sys/kernel/mm/transparent_hugepage/enabled
    sudo chmod go+w /sys/kernel/mm/transparent_hugepage/enabled
    sudo echo always > /sys/kernel/mm/transparent_hugepage/enabled
    sudo chmod go-w /sys/kernel/mm/transparent_hugepage/enabled
    sudo cat /sys/kernel/mm/transparent_hugepage/enabled
fi

export HSA_XNACK=${HSA_XNACK}
echo $ARGS, ${HSA_XNACK}, ${THP}, ${ROCR_VISIBLE_DEVICES}
if [[ $ROCPROF -eq 1 ]]; then
    rocprof --roctx-trace --hip-trace -d tprof_xnack_${HSA_XNACK} -t tprof_xnack_${HSA_XNACK}/tmp_${SLURM_PROCID} -o tprof_xnack_${HSA_XNACK}/pelelmex_1_4_${SLURM_PROCID}.csv ./PeleLMeX3d.hip.x86-genoa.TPROF.MPI.HIP.ex ${ARGS}
else    
    ./PeleLMeX3d.hip.x86-genoa.TPROF.MPI.HIP.ex ${ARGS}
fi

# Revert huge pages
if [[ $THP -eq 1 ]]; then
    sudo chmod go+w /sys/kernel/mm/transparent_hugepage/enabled
    sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled
    sudo chmod go-w /sys/kernel/mm/transparent_hugepage/enabled
    sudo cat /sys/kernel/mm/transparent_hugepage/enabled
fi

if [[ $MEMORY_PROFILE -eq 1 ]]; then
    pkill -f rocm-smi
fi
