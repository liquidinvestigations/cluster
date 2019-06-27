job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "prometheus" {
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

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/webserver_alert.yml"
        data = <<EOH
---
groups:
- name: prometheus_alerts
  rules:
  - alert: Webserver down
    expr: absent(up{job="webserver"})
    for: 10s
    labels:
      severity: critical
    annotations:
      description: "Our webserver is down."
EOH
      }

      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"
        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

alerting:
  alertmanagers:
  - consul_sd_configs:
    - server: '{{ "{{" }} env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['alertmanager']

rule_files:
  - "webserver_alert.yml"

scrape_configs:

  - job_name: 'alertmanager'

    consul_sd_configs:
    - server: '{{ "{{" }} env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['alertmanager']

  - job_name: 'nomad_metrics'

    consul_sd_configs:
    - server: '{{ "{{" }} env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['nomad-client', 'nomad']

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep

    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'webserver'

    consul_sd_configs:
    - server: '{{ "{{" }} env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['webserver']

    metrics_path: /metrics
EOH
      }
      driver = "docker"
      config {
        image = "prom/prometheus:v2.10.0"
        volumes = [
          "local/webserver_alert.yml:/etc/prometheus/webserver_alert.yml",
          "local/prometheus.yml:/etc/prometheus/prometheus.yml"
        ]
        port_map {
          http = 9090
        }
      }
      resources {
        network {
          mbits = 10
          port "http" {
          }
        }
      }
      service {
        name = "prometheus"
        port = "http"
        tags = ["fabio-/prometheus"]
        check {
          name     = "Prometheus alive on HTTP"
          type     = "http"
          path     = "/-/healthy"
          interval = "4s"
          timeout  = "2s"
        }
      }
    }
  }
}
