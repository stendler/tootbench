#!/usr/bin/env bash

username="$1"
if [ -z "$username" ]; then
  username="user" # default
fi

docker compose --project-directory mastodon run -it --rm --entrypoint "bash -c" tootctl "echo \"➔ creating user $username with email $username@\$(hostname)\" && tootctl accounts create $username --email $username@\$(hostname) --confirmed"
