#!/usr/bin/env sh

set -e

# only checking one arg is enough, since there are only 2 total and both is the default
instances="$1"
if [ -z $instances ]; then
  instances="instance client"
fi

terraform -chdir=terraform init
terraform -chdir=terraform apply $scenario $(for instance in $instances; do echo -replace=google_compute_instance.$instance; done) -auto-approve

./scripts/await-ssh.sh
