#!/usr/bin/env bash

username="$1"
if [ -z "$username" ]; then
  username="user" # default
fi

domain="$2"
if [ -z "$domain" ]; then
  domain="localhost"
fi

docker compose --project-directory mastodon run -it --rm --name "$domain" --entrypoint "bash -c" tootctl "echo \"➔ creating user $username with email $username@$domain\" && tootctl accounts create $username --email $username@$domain --confirmed"
