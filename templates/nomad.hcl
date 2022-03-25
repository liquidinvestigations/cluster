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

{% if not OPTIONS.client_only %}
server {
  enabled = true
  bootstrap_expect = {{OPTIONS.bootstrap_expect}}
  job_gc_threshold = "{{OPTIONS.nomad_zombie_time}}"
  heartbeat_grace = "35s"
  min_heartbeat_ttl =  "40s"
  num_schedulers = {{OPTIONS.nomad_schedulers}}

  default_scheduler_config {
    scheduler_algorithm = "spread"

    preemption_config {
      batch_scheduler_enabled   = true
      system_scheduler_enabled  = true
      service_scheduler_enabled = true
    }
  }

  {{OPTIONS.nomad_server_join}}
}
{% else %}
server {
  enabled = false
}
{% endif %}

client {
  enabled = true
  network_interface = "{{OPTIONS.nomad_interface}}"
  memory_total_mb = {{OPTIONS.nomad_memory or '0 # autodetect'}}
  {{OPTIONS.nomad_server_join}}
  gc_max_allocs = 300
  max_kill_timeout = "300s"

  # reserved for nomad, consul, OS
  reserved {
    cpu = 400
    memory = 400
    disk = 400
  }

  options {
    "fingerprint.blacklist" = "env_aws"
    # "docker.caps.whitelist" = "NET_ADMIN,CHOWN,DAC_OVERRIDE,FSETID,FOWNER,MKNOD,NET_RAW,SETGID,SETUID,SETFCAP, SETPCAP,NET_BIND_SERVICE,SYS_CHROOT,KILL,AUDIT_WRITE"
    # "docker.privileged.enabled" = "true"
    # "docker.volumes.enabled" = "true"
  }

  meta {
    {{OPTIONS.nomad_meta}}
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

plugin "docker" {
  config {
    allow_privileged = true
    pull_activity_timeout = "30m"
    volumes {
      enabled = true
    }
    allow_caps = ["net_admin", "chown", "dac_override", "fsetid", "fowner", "mknod", "net_raw", "setgid", "setuid", "setfcap", " setpcap", "net_bind_service", "sys_chroot", "kill", "audit_write"]
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
  collection_interval = "30s"
  disable_hostname = false
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

disable_anonymous_signature = true
disable_update_check = true

limits {
  https_handshake_timeout = "45s"
  http_max_conns_per_client = 300
  rpc_handshake_timeout = "45s"
  rpc_max_conns_per_client = 300
}
