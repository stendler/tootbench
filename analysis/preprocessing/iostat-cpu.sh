#!/usr/bin/env sh

# Cleanup and convert the iostat -c journalctl output to csv

if [ -f "$1" ]; then
  # header
  # avg-cpu
  echo "timestamp,timestamp_micro,host,process,user_util,user_nice,system_util,io_wait,steal,idle" | gzip
  zcat "$1" | grep -v "avg-cpu:" | grep -v "systemd" | grep -v "Linux" | sed -E 's/\./,/;s/\s+/,/g' | gzip
else
  echo 1>&2 "iostat-cpu log file not found"
  exit 1
fi
