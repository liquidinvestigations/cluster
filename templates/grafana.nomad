job "grafana" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "grafana" {
    restart {
      attempts = 10
      interval = "2m"
      delay = "10s"
      mode = "delay"
    }

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:6.3.5"
        port_map {
          http = 3000
        }
      }

      env {
        GF_PATHS_PROVISIONING = "/local/provisioning"

        GF_SECURITY_DISABLE_GRAVATAR = "true"

        GF_SERVER_ROOT_URL = "http://${attr.unique.network.ip-address}:9990/grafana"
        GF_SERVER_SERVE_FROM_SUB_PATH = "true"
        GF_SERVER_ENABLE_GZIP = "true"

        GF_AUTH_BASIC_ENABLED = "false"
        GF_AUTH_ANONYMOUS_ENABLED = "true"
        GF_AUTH_ANONYMOUS_ORG_NAME = "Main Org."
        GF_AUTH_ANONYMOUS_ORG_ROLE = "Admin"
      }

      resources {
        cpu    = 200
        memory = 250
        network {
          mbits = 10
          port "http" {}
        }
      }

      service {
        name = "grafana"
        port = "http"
        tags = ["fabio-/grafana"]
        check {
          name     = "Grafana alive on HTTP"
          type     = "http"
          path     = "/grafana/api/health"
          interval = "4s"
          timeout  = "2s"
        }
      }
    }
  }
}
