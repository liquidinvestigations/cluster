node_name = "{{OPTIONS.node_name}}"
server_name = "{{OPTIONS.node_name}}"
bind_addr = "{{OPTIONS.consul_address}}"
client_addr = "{{OPTIONS.consul_address}}"
addresses {
  http = "{{OPTIONS.consul_address}}"
}
data_dir = "{{PATH.consul_var}}"
datacenter = "dc1"
server = true
ui = true
bootstrap_expect = {{OPTIONS.bootstrap_expect}}
{{OPTIONS.consul_retry_join}}
telemetry {
  dogstatsd_addr = "{{OPTIONS.consul_address}}:8125"
  disable_hostname = false
}
ports {
  "grpc" = 8502
}
connect {
  enabled = true
}
