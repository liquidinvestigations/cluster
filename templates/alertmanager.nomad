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
          alertmanager_ui = 9093
        }
      }
      resources {
        network {
          mbits = 10
          port "alertmanager_ui" {
            static = 6661
          }
        }
      }
      service {
        name = "alertmanager"
        port = "alertmanager_ui"
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
