#!/usr/bin/env sh

# echo the client logs in the same style as the other preprocess tools

if [ -f "$1" ]; then
  # header
  echo "scenario,run,timestamp_iso,message_type,message_len,sender_username,sender_domain,message_timestamp,server_timestamp,receiver_username,receiver_domain" | gzip
  zcat "$1" | sed -E "s/@/,/g" | gzip
else
  echo 1>&2 "client log file not found"
  exit 1
fi
