#!/usr/bin/env sh

# Cleanup and convert the iostat -d journalctl output to csv

if [ -f "$1" ]; then
  # header
  echo "timestamp,timestamp_micro,host,process,device,transfer_per_second,MBps_read,MBps_written,MBps_discarded,MB_read,MB_written,MB_discarded" | gzip
  zcat "$1" | grep -v "Device" | sed -E 's/\./,/;s/\s+/,/g' | tail -n +3 | gzip
else
  echo 1>&2 "iostat-disk log file not found"
  exit 1
fi
