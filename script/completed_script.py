#!/usr/bin/env python3
import json
import os

import requests


def getFromEnv():
    env_var = str(os.environ.get("secret_free4all_some_secret", "not found"))
    print("---FROM ENV---")
    print("Your Secret :", env_var)
    print("\n")


def getFromAPI(token):
    response = requests.get(
        "http://localhost:8200" + "/v1/database/creds/mysql-ro-role",
        headers={"X-Vault-Token": token},
    )
    # 200 = OK, other = NOK
    if response.ok:
        user = response.json()["data"]["username"]
        passw = response.json()["data"]["password"]
        return user, passw
    else:
        response.raise_for_status()


getFromEnv()
print(
    f'"api" generated read-only mysql credentials in tuple format are: {getFromAPI(os.environ.get("VAULT_TOKEN", "not found"))}'
)
