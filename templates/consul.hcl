bind_addr = "{{OPTIONS.consul_address}}"
client_addr = "{{OPTIONS.consul_address}}"
addresses {
  http = "{{OPTIONS.consul_address}} unix://{{PATH.consul_socket}}"
}
data_dir = "{{PATH.consul_var}}"
datacenter = "dc1"
server = true
ui = true
bootstrap_expect = {{OPTIONS.bootstrap_expect}}
{{OPTIONS.consul_retry_join}}
