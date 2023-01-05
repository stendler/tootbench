#!/usr/bin/env sh

terraform -chdir=plans/single-instance  destroy -var-file=secrets.tfvars
