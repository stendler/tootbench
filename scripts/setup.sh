#!/usr/bin/env sh

set -e

terraform -chdir=terraform init $scenario_cmd
terraform -chdir=terraform apply $scenario_cmd

./scripts/await-ssh.sh
