# Simple Vault demo

## Prereqs
To use this demo, you will need to run:

```
pip install -r script/requirements.txt
```

After that, make sure you have the following apps installed:

- docker
- docker-compose
- jq
- envconsul
- vault

Finally just execute `run_me.sh`

## Description

This demo is a mixture of using curl, vault cli and python with requests library to communicate with Vault.

`docker-compose` is used to coordinate locally the required containers: `consul, vault and mysql`.

The setup will show how to run Vault using Consul as a backend. Configures MySQL secret engine and configures the dynamic secret plugin with a role.

A policy then is created to limit access to that mysql ro role.

Envconsul is used to show how to inject env variables to scripts, be it a bash or python script.

