#!/usr/bin/env sh

set -e

find analysis/input/*/ -type f -name vmstat.log.gz -exec sh -c 'outputfile=$(echo "{}" | sed "s/input/processed/"); mkdir -p $(dirname $outputfile); ./analysis/preprocessing/vmstat.sh "{}" > $outputfile'  \;
find analysis/input/*/ -type f -name iostat-cpu.log.gz -exec sh -c 'outputfile=$(echo "{}" | sed "s/input/processed/"); mkdir -p $(dirname $outputfile); ./analysis/preprocessing/iostat-cpu.sh "{}" > $outputfile'  \;
find analysis/input/*/ -type f -name iostat-disk.log.gz -exec sh -c 'outputfile=$(echo "{}" | sed "s/input/processed/"); mkdir -p $(dirname $outputfile); ./analysis/preprocessing/iostat-disk.sh "{}" > $outputfile'  \;
find analysis/input/*/ -type f -name mpstat.log.gz -exec sh -c 'outputfile=$(echo "{}" | sed "s/input/processed/"); mkdir -p $(dirname $outputfile); ./analysis/preprocessing/mpstat.sh "{}" > $outputfile'  \;
find analysis/input/*/ -type f -name docker-stats.log.gz -exec sh -c 'outputfile=$(echo "{}" | sed "s/input/processed/"); mkdir -p $(dirname $outputfile); ./analysis/preprocessing/docker-stats.sh "{}" > $outputfile'  \;
