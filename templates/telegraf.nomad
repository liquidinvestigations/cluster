job "telegraf" {
  datacenters = ["dc1"]
  type = "system"
  priority = 89

  group "telegraf" {
    task "telegraf" {
      driver = "docker"
      config {
        image = "telegraf:1.14-alpine"
        dns_servers = ["${attr.unique.network.ip-address}"]
        port_map {
          statsd = 8125
          http = 8123
        }
        args = ["--config", "/local/telegraf.conf"]

        volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
        network_mode = "host"
        privileged = true
        memory_hard_limit = 500
      }

      env {
        IP = "${attr.unique.network.ip-address}"
      }

      template {
        destination = "local/telegraf.conf"
        data = <<-EOF
          [agent]
            interval = "30s"
            flush_interval = "30s"
            omit_hostname = false
            debug = false
            quiet = false

          [[inputs.sensors]]
          [[inputs.docker]]
          [[inputs.cpu]]
            percpu = true
            totalcpu = true
            collect_cpu_time = false
          [[inputs.disk]]
          [[inputs.diskio]]
          [[inputs.kernel]]
          [[inputs.linux_sysctl_fs]]
          [[inputs.mem]]
          [[inputs.net]]
            interfaces = ["*"]
          [[inputs.netstat]]
          [[inputs.processes]]
          [[inputs.swap]]
          [[inputs.system]]
          [[inputs.procstat]]
            pattern = "(consul|vault)"

          [[inputs.statsd]]
            protocol = "udp"
            service_address = "${IP}:8125"
            delete_gauges = true
            delete_counters = true
            delete_sets = true
            delete_timings = true
            percentiles = [90]
            metric_separator = "_"
            parse_data_dog_tags = true
            allowed_pending_messages = 10000
            percentile_limit = 1000

          [[inputs.consul]]
            address = "http://consul.service.consul:8500"
            scheme = "http"

          [[inputs.prometheus]]
            urls = ["http://nomad.service.consul:4646/v1/metrics?format=prometheus"]

          # TODO collect vault metrics: Need Client Token set as header X-Vault-Token
          #[[inputs.prometheus]]
          #  urls = ["http://nomad.service.consul:8200/v1/sys/metrics?format=prometheus"]

          [[outputs.influxdb]]
            urls = ["http://cluster-fabio.service.consul:9990/influxdb"]
            database = "telegraf"
            skip_database_creation = true
            timeout = "9s"
            retention_policy = "autogen"

          [[outputs.health]]
            service_address = "http://${IP}:8123"
          EOF
      }

      resources {
        cpu    = 100
        memory = 150
        network {
          mbits = 1
          port "udp" { static = 8125 }
          port "http" { static = 8123 }
        }
      }

      service {
        name = "telegraf"
        port = "http"
        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "18s"
          timeout  = "14s"
        }
      }
    }
  }
}
