

job "grafana" {
  datacenters = ["dc1"]
  type = "service"

  group "grafana" {
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

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:6.2.4"
        port_map {
          http = 3000
        }
      }

      env {
        GF_LOG_LEVEL = "DEBUG"
        GF_LOG_MODE = "console"
        GF_PATHS_PROVISIONING = "/local/provisioning"
        GF_DEFAULT_INSTANCE_NAME = "cluster"

        GF_AUTH_BASIC_ENABLED = "false"
        GF_AUTH_ANONYMOUS_ENABLED = "true"
        GF_AUTH_ANONYMOUS_ORG_NAME = "Main Org."
        GF_AUTH_ANONYMOUS_ORG_ROLE = "Admin"
      }

      resources {
        cpu    = 500
        memory = 256
        network {
          mbits = 10
          port "http" {
          }
        }
      }

      service {
        name = "grafana"
        port = "http"
        tags = ["fabio-/grafana"]
        check {
          name     = "Grafana alive on HTTP"
          type     = "http"
          path     = "/api/health"
          interval = "4s"
          timeout  = "2s"
          check_restart {
            limit = 3
            grace = "20s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}
