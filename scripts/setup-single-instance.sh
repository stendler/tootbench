#!/usr/bin/env sh

set -e

if [ ! -d cert/mstdn-single-instance ]; then
  docker run --rm -v "$(pwd)/cert:/cert" -u $(id -u):$(id -g) minica --domains mstdn-single-instance
fi

terraform -chdir=plans/single-instance init
terraform -chdir=plans/single-instance apply -var-file="secrets.tfvars"

./scripts/await-ssh.sh
