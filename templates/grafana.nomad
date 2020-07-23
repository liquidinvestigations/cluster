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
        image = "grafana/grafana:7.0.5"
        dns_servers = ["${attr.unique.network.ip-address}"]
        port_map {
          http = 3000
        }
        memory_hard_limit = 3000
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

      template {
        destination = "/local/provisioning/dashboards/cluster.yaml"
        data = <<-EOF
          apiVersion: 1
          providers:
          - name: 'cluster'
            orgId: 1
            folder: ''
            type: file
            disableDeletion: false
            editable: true
            updateIntervalSeconds: 10
            options:
              path: /local/dashboards
          EOF
      }

      template {
        destination = "/local/provisioning/datasources/cluster.yaml"
        data = <<-EOF
          apiVersion: 1
          datasources:
          - {
            "access": "proxy",
            "basicAuth": false,
            "isDefault": false,
            "jsonData": {
                "httpMethod": "GET",
                "keepCookies": []
            },
            "name": "Prometheus",
            "readOnly": false,
            "type": "prometheus",
            "url": "http://cluster-fabio.service.consul:9990/prometheus",
            "version": 2,
            "withCredentials": false
          }
          - {
            "access": "proxy",
            "basicAuth": false,
            "isDefault": false,
            "jsonData": {
                "httpMethod": "GET",
                "keepCookies": []
            },
            "name": "InfluxDB",
            "readOnly": false,
            "database": "telegraf",
            "type": "influxdb",
            "url": "http://cluster-fabio.service.consul:9990/influxdb",
            "version": 2,
            "withCredentials": false
          }
          - {
            "access": "proxy",
            "basicAuth": false,
            "isDefault": false,
            "jsonData": {
                "interval": "Daily",
                "timeField": "timestamp",
                "esVersion": "60",
            },
            "name": "Hoover Elasticsearch Metrics",
            "readOnly": false,
            "type": "elasticsearch",
            "database": "[.monitoring-es-6-]YYYY.MM.DD",
            "url": "http://cluster-fabio.service.consul:9990/_es",
            "version": 2,
            "withCredentials": false
          }
          EOF
      }

      {% for filename in PATH.get_dashboards() %}
      template {
        destination = "/local/dashboards/{{ filename }}"
        left_delimiter = "I_HOPE_THIS"
        right_delimiter = "WONT_SHOW_UP"
        data = <<-EOF
          {{ PATH.load_dashboard(filename) }}
          EOF
      }
      {% endfor %}

      resources {
        cpu    = 200
        memory = 400
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
          interval = "14s"
          timeout  = "12s"
        }
      }
    }
  }
}
