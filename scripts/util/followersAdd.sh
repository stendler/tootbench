#!/usr/bin/env sh

set -e # exit on failure

if [ ! -d "$1" ]; then
  1="users"
fi

for file in $(find "$1" -name users.txt -not -path "*/$(hostname)/*"); do
  for username in $(cat "$file" | awk '{print $2}'); do
    docker compose --project-name mastodon run --rm tootctl accounts follow $username
  done
done
