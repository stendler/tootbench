#!/usr/bin/env sh

# echo the client logs in the same style as the other preprocess tools

if [ -f "$1" ]; then
  # header
  #echo "timestamp,timestamp_micro,host,process,container_id,name,cpu_pct,mem_usage,mem_limit,mem_pct,net_input,net_output,block_input,block_output,pid" | gzip
  cat "$1" | gzip # it wasn't really zipped at this point
else
  echo 1>&2 "client log file not found"
  exit 1
fi
