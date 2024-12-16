#!/bin/bash

CABINETS=( "x1000" "x1001" "x1002" "x1003" "x1004" "x1005" "x1006" "x1007" "x1008" "x1009" )


for CAB in "${CABINETS[@]}"; do
    NODES=`xhost-query.py "$CAB*" | grep "nodes:" | cut -d : -f 2`
    echo "$CAB: $NODES"
done
