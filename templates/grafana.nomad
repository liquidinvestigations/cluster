job "grafana" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "grafana" {
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

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:6.3.5"
        dns_servers = ["${attr.unique.network.ip-address}"]
        port_map {
          http = 3000
        }
        volumes = [
          "${meta.cluster_volumes}/grafana:/data",
        ]
      }

      env {
        GF_PATHS_DATA = "/data"
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
        destination = "/local/dashboards/nomad.json"
        data = <<-EOF
          {
            "annotations": {
              "list": [
                {
                  "builtIn": 1,
                  "datasource": "-- Grafana --",
                  "enable": true,
                  "hide": true,
                  "iconColor": "rgba(0, 211, 255, 1)",
                  "name": "Annotations & Alerts",
                  "type": "dashboard"
                }
              ]
            },
            "editable": true,
            "gnetId": null,
            "graphTooltip": 0,
            "links": [],
            "panels": [
              {
                "aliasColors": {},
                "bars": false,
                "dashLength": 10,
                "dashes": false,
                "datasource": "Prometheus",
                "fill": 1,
                "fillGradient": 0,
                "gridPos": {
                  "h": 12,
                  "w": 12,
                  "x": 0,
                  "y": 0
                },
                "id": 6,
                "legend": {
                  "avg": false,
                  "current": false,
                  "max": false,
                  "min": false,
                  "show": true,
                  "total": false,
                  "values": false
                },
                "lines": true,
                "linewidth": 1,
                "nullPointMode": "null",
                "options": {
                  "dataLinks": []
                },
                "percentage": false,
                "pointradius": 2,
                "points": false,
                "renderer": "flot",
                "seriesOverrides": [],
                "spaceLength": 10,
                "stack": false,
                "steppedLine": false,
                "targets": [
                  {
                    "expr": "(sum(nomad_client_allocated_memory))/1024",
                    "instant": false,
                    "refId": "A"
                  },
                  {
                    "expr": "sum(nomad_client_allocs_memory_usage)/1024/1024/1024",
                    "refId": "B"
                  },
                  {
                    "expr": "sum(nomad_client_host_memory_used)/1024/1024/1024",
                    "refId": "C"
                  },
                  {
                    "expr": "sum(nomad_client_host_memory_total)/1024/1024/1024",
                    "refId": "D"
                  }
                ],
                "thresholds": [],
                "timeFrom": null,
                "timeRegions": [],
                "timeShift": null,
                "title": "Memory",
                "tooltip": {
                  "shared": true,
                  "sort": 0,
                  "value_type": "individual"
                },
                "type": "graph",
                "xaxis": {
                  "buckets": null,
                  "mode": "time",
                  "name": null,
                  "show": true,
                  "values": []
                },
                "yaxes": [
                  {
                    "format": "short",
                    "label": null,
                    "logBase": 1,
                    "max": null,
                    "min": null,
                    "show": true
                  },
                  {
                    "format": "short",
                    "label": null,
                    "logBase": 1,
                    "max": null,
                    "min": null,
                    "show": true
                  }
                ],
                "yaxis": {
                  "align": false,
                  "alignLevel": null
                }
              },
              {
                "aliasColors": {},
                "bars": false,
                "dashLength": 10,
                "dashes": false,
                "datasource": "Prometheus",
                "fill": 1,
                "fillGradient": 0,
                "gridPos": {
                  "h": 12,
                  "w": 12,
                  "x": 12,
                  "y": 0
                },
                "id": 4,
                "legend": {
                  "avg": false,
                  "current": false,
                  "max": false,
                  "min": false,
                  "show": true,
                  "total": false,
                  "values": false
                },
                "lines": true,
                "linewidth": 1,
                "nullPointMode": "null",
                "options": {
                  "dataLinks": []
                },
                "percentage": false,
                "pointradius": 2,
                "points": false,
                "renderer": "flot",
                "seriesOverrides": [],
                "spaceLength": 10,
                "stack": false,
                "steppedLine": false,
                "targets": [
                  {
                    "expr": "sum(nomad_client_allocs_restart)",
                    "format": "time_series",
                    "instant": false,
                    "legendFormat": "",
                    "refId": "A"
                  },
                  {
                    "expr": "sum(nomad_client_allocs_failed)",
                    "format": "time_series",
                    "instant": false,
                    "refId": "B"
                  },
                  {
                    "expr": "sum(nomad_client_allocations_pending)",
                    "format": "time_series",
                    "instant": false,
                    "refId": "C"
                  }
                ],
                "thresholds": [],
                "timeFrom": null,
                "timeRegions": [],
                "timeShift": null,
                "title": "Churn",
                "tooltip": {
                  "shared": true,
                  "sort": 0,
                  "value_type": "individual"
                },
                "type": "graph",
                "xaxis": {
                  "buckets": null,
                  "mode": "time",
                  "name": null,
                  "show": true,
                  "values": []
                },
                "yaxes": [
                  {
                    "format": "short",
                    "label": null,
                    "logBase": 1,
                    "max": null,
                    "min": null,
                    "show": true
                  },
                  {
                    "format": "short",
                    "label": null,
                    "logBase": 1,
                    "max": null,
                    "min": null,
                    "show": true
                  }
                ],
                "yaxis": {
                  "align": false,
                  "alignLevel": null
                }
              }
            ],
            "schemaVersion": 19,
            "style": "dark",
            "tags": [],
            "templating": {
              "list": []
            },
            "time": {
              "from": "now-6h",
              "to": "now"
            },
            "timepicker": {
              "refresh_intervals": [
                "5s",
                "10s",
                "30s",
                "1m",
                "5m",
                "15m",
                "30m",
                "1h",
                "2h",
                "1d"
              ]
            },
            "title": "Nomad",
            "version": 1
          }
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
                "keepCookies": []
            },
            "name": "Loki",
            "readOnly": false,
            "type": "loki",
            "url": "http://cluster-fabio.service.consul:9990/loki",
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
          EOF
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
