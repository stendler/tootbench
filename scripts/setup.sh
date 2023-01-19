#!/usr/bin/env sh

set -e

if [ ! -d cert/mstdn-single-instance ]; then
  docker run --rm -v "$(pwd)/cert:/cert" -u $(id -u):$(id -g) minica --domains mstdn-single-instance
fi

terraform -chdir=terraform init $scenario
terraform -chdir=terraform apply $scenario

./scripts/await-ssh.sh
