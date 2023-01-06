#!/usr/bin/env bash

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

for i in `seq $number`; do
  username=$user$i
  echo "➔ creating user $username with email $username@$domain"
  newuser=$(docker compose --project-name mastodon run --rm --name "$domain" tootctl accounts create $username --email $username@$domain --confirmed | awk -v user=$username -v email="$username@$domain" '/New password:/ {print user, email, $3}')

  if [ -z "$newuser" ]; then
    echo "User creation failed. Already exists?"
    exit 1
  fi

  echo $newuser >> $(hostname).users.txt
  echo Created user: $newuser
done
