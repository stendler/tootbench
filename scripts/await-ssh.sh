#!/usr/bin/env sh

# NOTE: sed commands may require GNU sed and might not work with other POSIX implementations (e.g. on MacOS). But they work in the gcloud-terraform container

# gcloud compute config-ssh is not removing lines, that were edited, so they need to be disposed with the following
sed -i "/^# Google Compute Engine Section/,/^# End of Google Compute Engine Section/d" ~/.ssh/config
gcloud compute config-ssh --ssh-key-file=.ssh/id_ed25519

for instance in $(cat plans/single-instance/hosts); do
  sed -i "/^Host $instance/ s/[^ $instance]$/ $instance/" ~/.ssh/config
  sed -i "/^Host $instance/a\    User ansible" ~/.ssh/config
done

# await ssh-server ready for connections
# https://stackoverflow.com/questions/54668239/how-to-wait-until-ssh-is-available
until gcloud compute ssh ansible@mstdn-single-instance --ssh-key-file=.ssh/id_ed25519 --command="test -f .env.production" -- -o ConnectTimeout=2 2>/dev/null ; do
  sleep 1
  echo "Trying to connect..."
done

# make mastodon publicly available
ssh mstdn-single-instance sed -i \"/^ALTERNATE_DOMAINS=/ s/$/$(cat plans/single-instance/ip)/\" .env.production
(ssh mstdn-single-instance tail -f /var/log/cloud-init-output.log &) | awk '{print}; /cloud-init has finished/{exit}'

gcloud compute ssh controller --ssh-key-file=.ssh/id_ed25519 --command="true" # get host keys
ssh controller https mstdn-single-instance --ignore-stdin
