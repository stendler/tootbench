#!/usr/bin/env sh

set -e

instances="$1"
if [ -z $instances ]; then
  instances="instance controller"
fi

terraform -chdir=plans/single-instance apply $(for instance in $instances; do echo -replace=google_compute_instance.$instance; done) -var-file="secrets.tfvars" -auto-approve

./scripts/await-ssh.sh
