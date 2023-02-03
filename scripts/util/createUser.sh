#!/usr/bin/env bash
#
# Create users. Needs tootctl - e.g. via docker compose --project-name mastodon run --rm --name {{ hostname }} -v $(pwd)/createUser.sh:/createUser.sh --entrypoint=/createUser.sh tootctl {{ users }} user {{ hostname }} > users.txt
#

number="$1"
if [ -z "$number" ]; then
  number=1
fi

user="$2"
if [ -z "$user" ]; then
  user="user" # default
fi

domain="$3"
if [ -z "$domain" ]; then
  domain="localhost"
fi

for i in $(seq $number); do
  username=$user$i
  echo 1>&2 "➔ creating user $username with email $username@$domain"
  newuser=$(tootctl accounts create $username --email $username@$domain --confirmed | awk -v user=$username -v email="$username@$domain" '/New password:/ {print user, email, $3}')

  if [ -z "$newuser" ]; then
    echo 1>&2 "User creation failed. Already exists?"
    exit 1
  fi

  echo "$newuser"
  echo 1>&2 "Created user: $newuser"
done
