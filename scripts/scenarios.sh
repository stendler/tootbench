#!/usr/bin/env sh

# print all currently available scenarios
find terraform/scenarios -name "*.tfvars" | grep --only-matching "/\w*\." | grep --only-matching "\w*"
