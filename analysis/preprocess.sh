#!/usr/bin/env bash

set -e
set -o pipefail

# todo first find maybe not needed -> parameter and called with the main tootbench script
for timestamp in $(find playbooks/logs/ -mindepth 1 -maxdepth 1 -type d); do
  echo 1>&2 "preprocessing ... in $timestamp"
  for stat in vmstat iostat-cpu iostat-disk mpstat docker-stats tootbench; do
    printf 1>&2 "preprocessing ....... $stat    "
    for scenario in $(find "$timestamp" -mindepth 1 -maxdepth 1 -type d); do
      printf 1>&2 "\t%s " "$(basename "$scenario")"
      for run in $(find "$scenario" -mindepth 1 -maxdepth 1 -type d); do
        printf 1>&2 "%s " "$(basename "$run")"
        # add column scenario,run to csvs
        cat $(find "$run" -type f -name $stat.log.gz) | gzip -c -d | awk -v scenario="$(basename "$scenario")" -v run="$(basename "$run")" '{ print scenario","run","$0; }' | gzip > "$run/$stat.columned.log.gz"
      done
    done
    echo 1>&2
    cat $(find "$timestamp" -type f -name $stat.columned.log.gz) > "$timestamp/$stat.merged.log.gz" # care, this might be stuck if find does not return a file
    outputfile="$(echo "$timestamp" | sed "s/playbooks/analysis/;s/logs/input/")/$stat.log.gz"
    mkdir -p "$(dirname "$outputfile")"
    # preprocess them
    ./analysis/preprocessing/$stat.sh "$timestamp/$stat.merged.log.gz" > "$outputfile"
  done
done
