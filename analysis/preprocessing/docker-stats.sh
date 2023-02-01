#!/usr/bin/env sh

# Cleanup and convert the docker stats journalctl output to csv

if [ -f "$1" ]; then
  # header
  echo "timestamp,timestamp_micro,host,process,container_id,name,cpu_pct,mem_usage,mem_limit,mem_pct,net_input,net_output,block_input,block_output,pid" | gzip
  zcat "$1" | grep -v "blob data" | grep -v "systemd" | grep -v "CONTAINER" | grep -v " -- " | sed -E 's/%//g;s/\./,/;s/\///g;s/\s+/,/g' | gzip
else
  echo 1>&2 "docker stats log file not found"
  exit 1
fi
