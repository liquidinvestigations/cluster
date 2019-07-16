job "alertmanager" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

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
        args = [
          "--web.route-prefix=/alertmanager",
          "--web.external-url=http://{{OPTIONS.consul_address}}:9990/alertmanager",
         ]
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
          path     = "/alertmanager/-/healthy"
          interval = "4s"
          timeout  = "2s"
        }
      }
    }
  }
}
