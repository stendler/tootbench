#!/usr/bin/env sh

# NOTE: sed commands may require GNU sed and might not work with other POSIX implementations (e.g. on MacOS). But they work in the gcloud-terraform container

# gcloud compute config-ssh is not removing lines, that were edited, so they need to be disposed with the following
sed -i "/^# Google Compute Engine Section/,/^# End of Google Compute Engine Section/d" ~/.ssh/config
gcloud compute config-ssh --ssh-key-file=.ssh/id_ed25519

for instance in $(cat plans/single-instance/hosts); do
  sed -i "/^Host $instance/ s/$/ $instance/" ~/.ssh/config
  sed -i "/^Host $instance/a\    User ansible" ~/.ssh/config

  # await ssh-server ready for connections (and let gcloud gather fingerprints for known_hosts)
  # https://stackoverflow.com/questions/54668239/how-to-wait-until-ssh-is-available
  echo "Trying to connect to $instance..."
  until gcloud compute ssh ansible@$instance --ssh-key-file=.ssh/id_ed25519 --command="true" -- -o ConnectTimeout=2 2>/dev/null ; do
    sleep 1
    echo "Trying to connect to $instance..."
  done

done


ansible-playbook -i hosts.ini playbooks/setup.yml
# todo move everything below here (and the cloud-init runcmd's into ansible)

# make mastodon publicly available
# todo make sure the file is ready to be edited
ssh mstdn-single-instance sed -i \"/^ALTERNATE_DOMAINS=/ s/$/$(cat plans/single-instance/ip)/\" .env.production
#(ssh mstdn-single-instance tail -f /var/log/cloud-init-output.log &) | awk '{print}; /cloud-init has finished/{exit}'
ansible-playbook -i hosts.ini playbooks/setup-instance.yml

gcloud compute ssh controller --ssh-key-file=.ssh/id_ed25519 --command="true" # get host keys
ssh controller https mstdn-single-instance --ignore-stdin
