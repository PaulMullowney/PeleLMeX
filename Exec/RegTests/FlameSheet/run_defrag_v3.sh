#!/bin/bash

# Script to run the defragMI300A_v3 executable on all nodes in the current batch allocation.
# Adapted from defragMI300A.txt

nodeCt=$(flux resource list -n -o {nnodes})

#nodeCt=1
spindle_opts="-o userrc=/collab/usr/global/tools/spindle/toss_4_x86_64_ib_cray/etc/spindle/spindle.rc -o spindle"
affinity_opts="-o cpu-affinity=off -o gpu-affinity=off"
flux_opts="--tasks-per-node=1 -x -o exit-timeout=none --time-limit=15m"
output_opts="--output=defragMI300A.stdout --error=defragMI300A.stderr"
defragEXE=/usr/workspace/elcaphpe/utilities/defragMI300A_v3
set -x
flux run -N $nodeCt $output_opts $flux_opts $affinity_opts $spindle_opts $defragEXE
