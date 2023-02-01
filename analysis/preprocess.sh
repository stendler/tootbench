#!/usr/bin/env sh

set -e

for stat in vmstat iostat-cpu iostat-disk mpstat docker-stats; do
  for run in $(find playbooks/logs/ -mindepth 1 -maxdepth 1 -type d); do #  todo possibly change depth depending on naming (scenario name & rep)
    # merge found files
    cat $(find "$run" -type f -name $stat.log.gz) > "$run/$stat.log.merged.gz"
    outputfile="$(echo "$run" | sed "s/playbooks/analysis/;s/logs/input/")/$stat.log.gz"
    mkdir -p "$(dirname "$outputfile")"
    # preprocess them
    ./analysis/preprocessing/$stat.sh "$run/$stat.log.merged.gz" > "$outputfile"
  done
done
