name = "{{OPTIONS.node_name}}"
data_dir = "{{PATH.nomad_var}}"
leave_on_interrupt = true
leave_on_terminate = true

addresses {
  http = "{{OPTIONS.nomad_address}}"
  rpc = "{{OPTIONS.nomad_address}}"
  serf = "{{OPTIONS.nomad_address}}"
}

advertise {
  http = "{{OPTIONS.nomad_advertise}}"
  rpc = "{{OPTIONS.nomad_advertise}}"
  serf = "{{OPTIONS.nomad_advertise}}"
}

server {
  enabled = true
  bootstrap_expect = {{OPTIONS.bootstrap_expect}}
  job_gc_threshold = "{{OPTIONS.nomad_zombie_time}}"
  {{OPTIONS.nomad_retry_join}}
}

client {
  enabled = true
  network_interface = "{{OPTIONS.nomad_interface}}"
  memory_total_mb = {{OPTIONS.nomad_memory or '0 # autodetect'}}
  {{OPTIONS.nomad_client_servers}}
  gc_max_allocs = 300
  meta {
    {{OPTIONS.nomad_meta}}
  }
  options {
    "fingerprint.blacklist" = "env_aws"
    "docker.caps.whitelist" = "NET_ADMIN,CHOWN,DAC_OVERRIDE,FSETID,FOWNER,MKNOD,NET_RAW,SETGID,SETUID,SETFCAP, SETPCAP,NET_BIND_SERVICE,SYS_CHROOT,KILL,AUDIT_WRITE"
    "docker.privileged.enabled" = "true"
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

consul {
  address = "{{OPTIONS.consul_address}}:8500"
}

vault {
  enabled = true
  address = "http://{{OPTIONS.vault_address}}:8200"
}

telemetry {
  collection_interval = "10s"
  disable_hostname = false
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

disable_anonymous_signature = true
disable_update_check = true
