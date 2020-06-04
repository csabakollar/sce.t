#!/bin/bash

# shellcheck disable=SC1090
source "$(dirname "$0")"/lib/functions.sh

create_stack
initialise_vault
unseal_vault
configure_vault
create_policy
create_sample_secret_as_root
read_back_sample_secret_as_root
create_token
read_back_sample_secret_as_temp
get_userpass_with_completed_python_script
echo "Press any key to tear down the stack"
read -rn1
delete_stack
