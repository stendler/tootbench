#!/usr/bin/env sh

#cmd='docker compose --project-name mastodon run --rm -i --entrypoint="/bin/bash" tootctl'
cmd='docker run -i --rm tootsuite/mastodon'

RAKE_SECRET_KEY=$($cmd bundle exec rake secret)
RAKE_SECRET_OTP=$($cmd bundle exec rake secret)

# VAPID_PRIVATE_KEY & VAPID_PUBLIC_KEY
export $($cmd bundle exec rake mastodon:webpush:generate_vapid_key)

echo "  - rake-secret-key: $RAKE_SECRET_KEY"
echo "    rake-secret-otp: $RAKE_SECRET_OTP"
echo "    vapid-private-key: $VAPID_PRIVATE_KEY"
echo "    vapid-public-key: $VAPID_PUBLIC_KEY"
