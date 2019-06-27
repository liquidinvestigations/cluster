job "alertmanager" {
  datacenters = ["dc1"]
  type = "service"

  group "alerting" {
    restart {
      attempts = 10
      interval = "5m"
      delay = "10s"
      mode = "delay"
    }

    ephemeral_disk {
      size = 300
      sticky = true
    }

    task "alertmanager" {
      driver = "docker"
      config {
        image = "prom/alertmanager:v0.17.0"
        port_map {
          http = 9093
        }
      }
      resources {
        memory = 200
        network {
          mbits = 10
          port "http" {
          }
        }
      }
      service {
        name = "alertmanager"
        port = "http"
        tags = ["fabio-/alertmanager"]
        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "4s"
          timeout  = "2s"
        }
      }
    }
  }
}
