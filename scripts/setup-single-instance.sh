#!/usr/bin/env bash

set -e

(
cd plans/single-instance

terraform init
terraform apply
)

gcloud compute config-ssh --ssh-key-file=.ssh/id_ed25519
#ssh-keyscan mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22
rsync -azh --filter=':- .gitignore' --exclude=.git . mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22:project
# gcloud compute scp . ansible@mstdn-single-instance:~ --compress --dry-run --recurse --ssh-key-file=.ssh/id_ed25519
ssh mstdn-single-instance.europe-west1-b.cloud-service-benchmarking-22 docker version

