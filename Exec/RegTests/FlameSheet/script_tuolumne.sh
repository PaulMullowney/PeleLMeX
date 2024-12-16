#!/bin/bash

ranks=1
nodes=1
cfrhs_multi_kernel=1
cfrhs_min_blocks=2
gam=0
max_step=20
arena_size=4e10
size=256

cab=-1
xnack=0
thp=0
defrag=0
rprof=0
ntrials=1

for i in "$@"; do
    case "$1" in
        -nodes=*|--nodes=*)
            nodes="${i#*=}"
            shift # past argument=value
            ;;
        -ranks=*|--ranks=*)
            ranks="${i#*=}"
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
	-rprof|--rprof)
            rprof=1
            shift # past argument=value
            ;;
	-xnack|--xnack)
            xnack=1
            shift # past argument=value
            ;;
	-thp|--thp)
            thp=1
            shift # past argument=value
            ;;
	-defrag|--defrag)
            defrag=1
            shift # past argument=value
            ;;
        -cab=*|--cab=*)
            cab="${i#*=}"
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
odir=tuolumne_runs_${date}
if [[ ! -d ${odir} ]]; then
    echo "Making directory"
    mkdir -p ${odir}
fi

sed "s/%GPN%/$gpn/g;s/%RANKS%/$ranks/g;s/%NODES%/$nodes/g;s/%GAM%/$gam/g;s/%SIZE%/$size/g;s/%ARENA_SIZE%/$arena_size/g;s/%MAX_STEP%/$max_step/g;s/%CFRHS_MULTI_KERNEL%/$cfrhs_multi_kernel/g;s/%CFRHS_MIN_BLOCKS%/$cfrhs_min_blocks/g;s/%RPROF%/$rprof/g;s/%XNACK%/$xnack/g;s/%THP%/$thp/g;s/%DEFRAG%/$defrag/g;s/%NTRIALS%/$ntrials/g;" run_tuolumne.batch.i > run_tuolumne.batch

rm pele.err pele.out

if [[ $cab == -1 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out run_tuolumne.batch
elif [[ $cab == 0 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1001-1128] run_tuolumne.batch
elif [[ $cab == 1 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1129-1256] run_tuolumne.batch
elif [[ $cab == 2 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1257-1384] run_tuolumne.batch
elif [[ $cab == 3 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1385-1512] run_tuolumne.batch
elif [[ $cab == 4 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1513-1640] run_tuolumne.batch
elif [[ $cab == 5 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1641-1768] run_tuolumne.batch
elif [[ $cab == 6 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1769-1896] run_tuolumne.batch
elif [[ $cab == 7 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[1897-2024] run_tuolumne.batch
elif [[ $cab == 8 ]]; then
    flux batch -t 2h -N $nodes --job-name=pele --error=${odir}/pele_${nodes}.err --output=${odir}/pele_${nodes}.out --requires=hosts:tuolumne[2025-2152] run_tuolumne.batch
fi
