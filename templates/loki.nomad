job "loki" {
  datacenters = ["dc1"]
  type = "system"
  priority = 95

  group "loki" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }

    restart {
      attempts = 10
      interval = "2m"
      delay = "10s"
      mode = "delay"
    }

    task "loki" {
      driver = "docker"

      config {
        image = "grafana/loki:master"
        volumes = [
          "${meta.cluster_volumes}/loki:/tmp/loki",
        ]
        port_map {
          http = 3100
        }
      }

      resources {
        cpu = 200
        memory = 1000
        network {
          mbits = 10
          port "http" {
            static = 3100
          }
        }
      }

      service {
        name = "loki"
        port = "http"
        tags = ["fabio-/loki strip=/loki"]
        check {
          name     = "tcp"
          type     = "tcp"
          interval = "4s"
          timeout  = "2s"
        }
      }
    }
  }
}
