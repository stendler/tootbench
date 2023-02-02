#!/usr/bin/env sh

# echo the client logs in the same style as the other preprocess tools

if [ -f "$1" ]; then
  # header
  echo "scenario,run,timestamp_iso,message_type,sender_username,message_timestamp,server_timestamp,receiver_username" | gzip
  cat "$1"
else
  echo 1>&2 "client log file not found"
  exit 1
fi
