storage "consul" {
  address = "{{OPTIONS.consul_address}}:8500"
  path = "vault/"
}

listener "tcp" {
  address = "{{OPTIONS.vault_address}}:8200"
  tls_disable = 1
}

ui = true
disable_mlock = {{'true' if OPTIONS.vault_disable_mlock else 'false'}}
api_addr = "http://{{OPTIONS.vault_address}}:8200"
