#!/usr/bin/env bash
#
# Prefix scenario name and run repetition number to each csv row, then merge all into one file for each monitored stat
#

set -e
set -o pipefail

folders="$*"
if [ -z "$folders" ]; then
  folders=$(find playbooks/logs/ -mindepth 1 -maxdepth 1 -type d)
fi

for timestamp in $folders; do
  echo 1>&2 "preprocessing in $timestamp"
  for stat in vmstat iostat-cpu iostat-disk mpstat docker-stats tootbench ping; do
    printf 1>&2 "preprocessing ... $stat "
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
