#!/usr/bin/env bash

set -e

if [ ! -d cert/mstdn-single-instance ]; then
  docker run --rm -v "$(pwd)/cert:/cert" -u $(id -u):$(id -g) minica --domains mstdn-single-instance
fi

terraform -chdir=plans/single-instance init
terraform -chdir=plans/single-instance apply -var-file="secrets.tfvars"

gcloud compute config-ssh --ssh-key-file=.ssh/id_ed25519
#ssh-keyscan mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22
#rsync -azh --filter=':- .gitignore' --exclude=.git . mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22:project
#ssh mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22 docker version

