#!/usr/bin/env sh

if [ ! -f "$1" ]; then
  echo "Needs a text file listing users. Could not find file $1"
  exit 1
fi

# will that even work for remote users?
# local can only be added with $username and not via $username@domain
for username in $(cat "$1" | awk '{print $1}'); do
  docker compose --project-name mastodon run --rm tootctl accounts follow $username &
done

wait
