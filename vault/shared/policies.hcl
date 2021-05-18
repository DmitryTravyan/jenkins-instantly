# Dev servers have version 2 of KV secrets engine mounted by default, so will
# need these paths to grant permissions:
path "secret/jenkins/bsp/*" {
  capabilities = ["create", "update", "read"]
}

path "secret/jenkins/middle/*" {
  capabilities = ["create", "update", "read"]
}
