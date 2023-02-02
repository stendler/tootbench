#!/usr/bin/env sh

# Cleanup and convert the vmstat journalctl output to csv

if [ -f "$1" ]; then
  # header
  echo "scenario,run,timestamp,timestamp_micro,host,process,runnable_processes,blocked_processes,swap,free,buff,cache,swapped_from_disk,swapped_to_disk,blocks_received,blocks_sent,interrupts,context_switches,user_time,kernel_time,idle,waiting,stolen" | gzip
  zcat "$1" | grep -v "systemd" | grep -v "memory---" | grep -v "swpd" | sed -E 's/\./,/;s/\s+/,/g' | gzip
else
  echo 1>&2 "vmstat log file not found"
  exit 1
fi
