#!/usr/bin/env sh

gcloud compute config-ssh --ssh-key-file=.ssh/id_ed25519

# await ssh-server ready for connections
# https://stackoverflow.com/questions/54668239/how-to-wait-until-ssh-is-available
until gcloud compute ssh mstdn-single-instance --ssh-key-file=.ssh/id_ed25519 --command=true -- -o ConnectTimeout=5 2>&1; do
  sleep 1
  echo "Trying to connect..."
done

(gcloud compute ssh mstdn-single-instance --ssh-key-file=.ssh/id_ed25519 --command="tail -f /var/log/cloud-init-output.log" &) | awk '{print}; /cloud-init has finished/{exit}'
gcloud compute ssh controller --ssh-key-file=.ssh/id_ed25519 --command="https mstdn-single-instance --ignore-stdin"
