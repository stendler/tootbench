#!/usr/bin/env sh

# Cleanup and convert the merged ping@ journalctl output to csv

if [ -f "$1" ]; then
  # header
  echo "scenario,run,timestamp,timestamp_micro,host,process,size_bytes,target,ip,icmp_seq,ttl,ping_time,ping_time_unit" | gzip
  zcat "$1" | grep -v "systemd" | grep -v "PING" | sed -E 's/\./,/;s/bytes from//;s/\(|\)|://g;s/icmp_seq=//;s/ttl=//;s/time=//;s/\s+/,/g' | gzip
else
  echo 1>&2 "ping log file not found"
  exit 1
fi
