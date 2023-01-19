#!/usr/bin/env sh

# print all currently available scenarios
find terraform/scenarios -name "*.tfvars" | grep -o "/\w*\." | grep -o "\w*"
