#!/bin/bash -l

ranks=1
nodes=1
cfrhs_multi_kernel=1
cfrhs_min_blocks=2
gam=0
max_step=20
arena_size=4e10
size=256
ntrials=1

for i in "$@"; do
    case "$1" in
        -ranks=*|--ranks=*)
            ranks="${i#*=}"
            shift # past argument=value
            ;;
        -nodes=*|--nodes=*)
            nodes="${i#*=}"
            shift # past argument=value
            ;;
        -arena_size=*|--arena_size=*)
            arena_size="${i#*=}"
            shift # past argument=value
            ;;
        -size=*|--size=*)
            size="${i#*=}"
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
		  -gam|--gam)
            gam=1
            shift # past argument=value
            ;;
		  -ntrials=*|--ntrials=*)
            ntrials="${i#*=}"
            shift # past argument=value
            ;;
        --)
            shift
            break
            ;;
    esac
done

gpn=$((ranks/nodes))
date=$(date '+%Y-%m-%d')

sed "s/%GPN%/$gpn/g;s/%RANKS%/$ranks/g;s/%NODES%/$nodes/g;s/%GAM%/$gam/g;s/%SIZE%/$size/g;s/%ARENA_SIZE%/$arena_size/g;s/%MAX_STEP%/$max_step/g;s/%CFRHS_MULTI_KERNEL%/$cfrhs_multi_kernel/g;s/%CFRHS_MIN_BLOCKS%/$cfrhs_min_blocks/g;s/%DATE%/$date/g;s/%NTRIALS%/$ntrials/g;" run_frontier.batch.i > run_frontier.batch
sbatch run_frontier.batch
