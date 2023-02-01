#!/usr/bin/env sh

# Cleanup and convert the mpstat journalctl output to csv

if [ -f "$1" ]; then
  # header
  echo "timestamp,timestamp_micro,host,process,time,CPU,user_util_pct,nice_util_pct,sys_util_pct,iowait_pct,hw_interrupt_pct,sw_interrupt_pct,steal_pct,guest_pct,nice_guest,idle_pct" | gzip
  zcat "$1" | sed -E 's/\./,/;s/\s+/,/g' | grep -v "systemd" | grep -v "CPU" | gzip
else
  echo 1>&2 "mpstat log file not found"
  exit 1
fi
