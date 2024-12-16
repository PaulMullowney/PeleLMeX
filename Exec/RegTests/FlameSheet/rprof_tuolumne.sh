#!/bin/bash
rocprof --roctx-trace --hip-trace -d ${ODIR}/profile_${STR} -t ${ODIR}/profile_${STR}/tmp_${FLUX_TASK_LOCAL_ID} -o ${ODIR}/profile_${STR}/pelelmex_${FLUX_TASK_LOCAL_ID}.csv ./PeleLMeX3d.hip.x86-genoa.TPROF.MPI.HIP.ex ${ARGS}
