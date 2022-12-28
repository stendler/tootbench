#!/usr/bin/env bash

username="$1"
if [ -z "$username" ]; then
  username="rootOfAllEvil" # default
fi

docker compose --project-directory mastodon run -it --rm --entrypoint "bash -c" tootctl "echo \"➔ creating owner $username with email $username@\$(hostname)\" && tootctl accounts create $username --email $username@\$(hostname) --confirmed --role Owner"
