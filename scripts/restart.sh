#!/usr/bin/env sh

set -e

# only checking one arg is enough, since there are only 2 total and both is the default
resources="$1"
if [ -z $resources ]; then
  resources="instance client"
fi

let n=$(cat terraform/hosts | wc -l)-1
resources=$(echo $resources | sed --expression "s/instance/$(for i in $(seq 0 $n); do printf instance[$i]\ ; done)/")

terraform -chdir=terraform init
terraform -chdir=terraform apply $scenario_cmd $(for resource in $resources; do echo -replace="google_compute_instance.$resource"; done) -auto-approve

./scripts/await-ssh.sh
