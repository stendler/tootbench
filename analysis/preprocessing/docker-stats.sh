#!/usr/bin/env sh

# Cleanup and convert the docker stats journalctl output to csv

if [ -f "$1" ]; then
  # header
  echo "timestamp,host,process,container_id,name,cpu_pct,mem_usage,mem_limit,mem_pct,net_input,net_output,block_input,block_output,pid" | gzip
  zcat "$1" | grep -v "blob data" | sed -E 's/\//;s/\s+/,/g' | tail -n +2 | gzip
else
  echo 1>&2 "docker stats log file not found"
  exit 1
fi
