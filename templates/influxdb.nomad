job "influxdb" {
  datacenters = ["dc1"]
  type = "service"
  priority = 89

  group "influxdb" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }

    task "influxdb" {
      driver = "docker"
      config {
        image = "influxdb:1.5-alpine"
        dns_servers = ["${attr.unique.network.ip-address}"]
        port_map {
          http = 8086
        }
        volumes = [
          "${meta.cluster_volumes}/influxdb:/var/lib/influxdb",
        ]
      }

      env {
        INFLUXDB_DB = "telegraf"
      }

      resources {
        cpu    = 100
        memory = 150
        network {
          mbits = 1
          port "http" { static = 9989 }
        }
      }

      service {
        name = "influxdb"
        port = "http"
        tags = ["fabio-/influxdb strip=/influxdb"]
        check {
          name     = "http"
          type     = "http"
          path     = "/ping"
          interval = "8s"
          timeout  = "4s"
        }
      }
    }
  }
}
