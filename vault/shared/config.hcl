storage "file" {
  path    = "/data/vault/storage"
}

listener "tcp" {
  address     = "0.0.0.0:10002"
  tls_disable = "true"
}
disable_mlock = true
ui = false

api_addr = "http://0.0.0.0:10002"
disable_clustering = true
