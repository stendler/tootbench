#!/usr/bin/env sh

# NOTE: sed commands may require GNU sed and might not work with other POSIX implementations (e.g. on MacOS). But they work in the gcloud-terraform container

# gcloud compute config-ssh is not removing lines, that were edited, so they need to be disposed with the following
if [ -f ~/.ssh/config ]; then
  sed -i "/^# Google Compute Engine Section/,/^# End of Google Compute Engine Section/d" ~/.ssh/config
fi
gcloud compute config-ssh --ssh-key-file=.ssh/id_ed25519

# if running inside docker: to be able to mount a volume from the host
if [ -z "$HOST_VOLUME_MOUNT" ]; then
  HOST_VOLUME_MOUNT="$(pwd)"
  echo "No HOST_VOLUME_MOUNT set. Assuming running on the host and the following directory is accessible by the docker daemon: $HOST_VOLUME_MOUNT"
fi

for instance in $(cat terraform/hosts); do
  sed -i "/^Host $instance/ s/$/ $instance/" ~/.ssh/config
  sed -i "/^Host $instance/a\    User ansible" ~/.ssh/config

  if [ ! -d cert/$instance ]; then
    docker run --rm -v "$HOST_VOLUME_MOUNT/cert:/cert" -u $(id -u):$(id -g) minica --domains $instance
  fi

  # await ssh-server ready for connections (and let gcloud gather fingerprints for known_hosts)
  # https://stackoverflow.com/questions/54668239/how-to-wait-until-ssh-is-available
  echo "Trying to connect to $instance..."
  until gcloud compute ssh ansible@$instance --ssh-key-file=.ssh/id_ed25519 --command="true" -- -o ConnectTimeout=2 2>/dev/null ; do
    sleep 1
    echo "Trying to connect to $instance..."
  done

done

# wait for ansible to be able to ssh and cloud-init to finish
ansible-playbook -i hosts.ini playbooks/await-init.yml

# wait for cloud-init to finish
#(ssh mstdn-single-instance tail -f /var/log/cloud-init-output.log &) | awk '{print}; /cloud-init has finished/{exit}'

# verify that instance is reachable from the client
#ssh controller https mstdn-single-instance/v1/instance --ignore-stdin
