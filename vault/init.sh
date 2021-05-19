#!/bin/bash

vault_unseal_key=$(echo $vault_init_body | jq -r '.keys[0]')
vault_token=$(echo $vault_init_body | jq -r '.root_token')
vault_unseal_body="{\"key\":\"$vault_unseal_key\"}"
echo "key: $vault_unseal_key token: $vault_token"
curl --data "$vault_unseal_body" https://vault.local/v1/sys/unseal | jq
x_vault_token="X-Vault-Token:$vault_token"
curl -H $x_vault_token -X POST --data '{\"type\":\"approle\"}' https://vault.local/v1/sys/auth/approle
curl -H $x_vault_token -X POST --data '{ \"type\":\"kv-v2\" }' https://vault.local/v1/sys/mounts/secret
curl -H $x_vault_token -X PUT --data @vault/system-policy.json https://vault.local/v1/sys/policies/acl/system
curl -H $x_vault_token -X PUT --data @vault/shared-policy.json https://vault.local/v1/sys/policies/acl/shared
curl -H $x_vault_token -X PUT --data '{\"policies\": [\"system\"]}' https://vault.local/v1/auth/approle/role/jenkins
curl -H $x_vault_token -X PUT --data '{\"policies\": [\"shared\"]}' https://vault.local/v1/auth/approle/role/jdsl

jen_role_id=$(curl -H $x_vault_token -X GET https://vault.local/v1/auth/approle/role/jenkins/role-id | jq -r .data.role_id)
jen_secret_id=$(curl -H $x_vault_token -X POST https://vault.local/v1/auth/approle/role/jenkins/secret-id | jq -r .data.secret_id)
echo "role_id: $jen_role_id secret_id: $jen_secret_id"
jen_login_body="{\"role_id\":\"$jen_role_id\",\"secret_id\":\"$jen_secret_id\"}"
jen_client_token=$(curl -X POST --data $jen_login_body https://vault.local/v1/auth/approle/login | jq -r .auth.client_token )

jdsl_role_id=$(curl -H $x_vault_token -X GET https://vault.local/v1/auth/approle/role/jdsl/role-id | jq -r .data.role_id)
jdsl_secret_id=$(curl -H $x_vault_token -X POST https://vault.local/v1/auth/approle/role/jdsl/secret-id | jq -r .data.secret_id)
echo "role_id: $jdsl_role_id secret_id: $jdsl_secret_id"
jdsl_login_body="{\"role_id\":\"$jdsl_role_id\",\"secret_id\":\"$jen_secret_id\"}"
jdsl_client_token=$(curl -X POST --data $jdsl_login_body https://vault.local/v1/auth/approle/login | jq -r .auth.client_token )
