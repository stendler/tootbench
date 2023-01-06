#!/usr/bin/env bash

username="$1"
if [ -z "$username" ]; then
  username="rootOfAllEvil" # default
fi

domain="$2"
if [ -z "$domain" ]; then
  domain="localhost"
fi

echo "➔ creating owner $username with email $username@$domain"
newuser=$(docker compose --project-name mastodon run -it --rm --name "$domain" tootctl accounts create $username --email $username@$domain --confirmed --role Owner | awk -v user=$username -v email="$username@$domain" '/New password:/ {print user, email, $3}')

if [ -z "$newuser" ]; then
  echo "User creation failed. Already exists?"
  exit 1
fi

echo $newuser >> admin.txt
echo Created admin user: $newuser
