#!/bin/bash

export VAULT_ADDR=http://localhost:8200

die() {
    # nicer exit function
    echo "ERROR: $*"
    exit 1
}

section_divider() {
    echo
    echo ============
    echo
}

create_stack() {
    # runs docker-compose if needed

    # making sure the user has everything, which is needed for the demo to work
    __check_command_exists() {
        # for staying D.R.Y.
        local cmd=$1
        if ! which "$cmd" >/dev/null; then
            die "Please install $cmd to run this demo"
        fi
    }

    __check_command_exists docker
    __check_command_exists docker-compose
    __check_command_exists jq
    __check_command_exists envconsul
    __check_command_exists vault

    echo "Creating Consul, Vault and MySQL containers"
    if [ "$(docker ps -aq --filter label=scetestapp |wc -l)" -eq 0 ]; then
        docker-compose up -d || die "something went wrong"
    else
        echo "Found some old containers..."
        delete_stack
        docker-compose up -d
    fi
    section_divider
}

initialise_vault() {
    __check_service() {
        local host=$1
        local port=$2
        while true; do
            sleep 1
            if nc -z "$host" "$port" 2>/dev/null; then
                return 0
            fi
        done
    }
    __check_vault_init() {
        # checks if vault is already initialised or not
        echo "Checking whether Vault is initialised"
        if __check_service localhost 8200; then
            if [ "$(curl -s localhost:8200/v1/sys/init |jq -r .initialized)" == "false" ]; then
                return 1
            else
                return 0
            fi
        fi
    }
    # initialises vault
    echo "Initialising Vault (for demo purposes only 1 key will be generated for unsealing)"
    echo "This setup is not recommended for production use"
    if ! __check_vault_init; then
        response=$(curl -s -XPUT --data @vault/init.json http://127.0.0.1:8200/v1/sys/init)
        root_token=$(echo "$response" |jq -r .root_token || die "couldn't extract the root token, maybe initialisation failed")
        key=$(echo "$response"| jq -r .keys[0] || die "couldn't extract the unsealing key, maybe initialisation failed")
        export VAULT_TOKEN=$root_token
    else
        die "something went wrong, Vault is already initialised"
    fi
    section_divider
}

unseal_vault() {
    # unseals vault
    echo "Unsealing Vault"
    if [ "$(curl -s -XPUT localhost:8200/v1/sys/unseal -d "{\"key\":\"$key\"}" |jq -r .sealed)" != "false" ]; then
        die "Failed to unseal Vault, please take a look at its logs."
    fi
    echo "Successfully unsealed."
    section_divider
}

configure_vault() {
    echo -e "Mounting database secret engine in Vault\c"
    curl -sf -H "X-Vault-Token: $root_token" -XPOST -d @vault/secret_engine_db.json http://127.0.0.1:8200/v1/sys/mounts/database || die "failed to enable the secret engine"
    echo " ...done."

    echo -e "Mounting kv secret engine in Vault\c"
    curl -sf -H "X-Vault-Token: $root_token" -XPOST -d @vault/secret_engine_kv.json http://127.0.0.1:8200/v1/sys/mounts/secret || die "failed to enable the secret engine"
    echo " ...done."

    # crude solution, until I find a more elegant one to wait for mysql to initialise
    # port checking is giving false positive
    echo -e "Waiting for MySQL to initialise...\c"
    sleep 15
    echo " ...done."

    echo -e "Enabling and configuring MySQL plugin connection in Vault\c"
    curl -sf -H "X-Vault-Token: $root_token" -XPOST -d @vault/mysql_plugin.json http://127.0.0.1:8200/v1/database/config/test-mysql >/dev/null || die "failed to configure the connection"
    echo " ...done."

    echo -e "Creating the readonly role in Vault\c"
    curl -s -H "X-Vault-Token: $root_token" -XPOST -d @vault/role_mysql_ro.json http://127.0.0.1:8200/v1/database/roles/mysql-ro-role || die "failed to create the role"
    echo " ...done."
    section_divider
}

create_policy() {
    echo -e "Creating the policy, which only allows access to getting a ro userpass to MySQL in Vault\c"
    curl -sf -H "X-Vault-Token: $root_token" -XPOST -d @vault/gen_ro_creds_policy.json http://127.0.0.1:8200/v1/sys/policy/mysql-ro-only || die "failed to create the role"
    echo " ...done."
    section_divider
}

create_sample_secret_as_root() {
    echo -e "Creating a sample secret as root\c"
    curl -sf -H "X-Vault-Token: $root_token" -XPOST -d @vault/sample_secret.json http://127.0.0.1:8200/v1/secret/sample-secret || die "failed to create the sample secret"
    echo " ...done."
    section_divider
}

read_back_sample_secret_as_root() {
    echo -e "Reading back the sample secret with root token"
    vault kv get secret/sample-secret || die "failed to read sample secret back"
    section_divider
}

create_token() {
    echo -e "Creating a new token for root\c"
    local response
    response="$(curl -sf -H "X-Vault-Token: $root_token" -XPOST -d @vault/token_limited_perm.json http://127.0.0.1:8200/v1/auth/token/create || die "failed to create a temp token")"
    temp_token="$(echo "$response"|jq -r .auth.client_token)"
    echo " ...done."
    section_divider
}

read_back_sample_secret_as_temp() {
    echo -e "Reading back the sample secret with temp_token, we should receive an error now:"
    VAULT_TOKEN="$temp_token" vault kv get secret/sample-secret
    section_divider
}

get_userpass_with_completed_python_script() {
    echo "Using the python script to get secrets from Vault using envconsul and using python function with requests to get the ro mysql creds"
    VAULT_TOKEN="$temp_token" vault kv put secret/free4all/some secret="the cake is a lie"
    VAULT_TOKEN="$temp_token" envconsul -config=envconsul/config.hcl -secret=secret/free4all/some ./script/completed_script.py
    section_divider
}

delete_stack() {
    # func tear down
    echo "Stopping Consul, Vault and MySQL containers"
    docker-compose down
}
