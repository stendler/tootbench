#!/usr/bin/env sh

set -e

terraform -chdir=terraform init $scenario
terraform -chdir=terraform apply $scenario

./scripts/await-ssh.sh
