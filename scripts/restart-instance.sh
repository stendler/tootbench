#!/usr/bin/env sh

set -e

instances="$1"
if [ -z $instances ]; then
  instances="instance client"
fi

terraform -chdir=terraform init
terraform -chdir=terraform apply $(for instance in $instances; do echo -replace=google_compute_instance.$instance; done) -auto-approve

./scripts/await-ssh.sh
