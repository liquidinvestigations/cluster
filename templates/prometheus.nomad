job "prometheus" {
  datacenters = ["dc1"]
  type = "service"
  priority = 90

  group "prometheus" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }

    reschedule {
      unlimited = true
      attempts = 0
      delay = "40s"
    }

    restart {
      attempts = 3
      interval = "18s"
      delay = "4s"
      mode = "fail"
    }

    ephemeral_disk {
      size = 300
      sticky = true
    }

    task "prometheus" {
      template {
        data = <<EOF
{% include 'prometheus_rules.yml' %}
        EOF
        destination = "local/prometheus_rules.yml"
      }

      template {
        data = <<EOF
{% include 'prometheus.yml' %}
        EOF
        destination = "local/prometheus.yml"
      }
      driver = "docker"
      config {
        image = "prom/prometheus:v2.10.0"
        args = [
          "--web.route-prefix=/prometheus",
          "--web.external-url=http://${attr.unique.network.ip-address}:9990/prometheus",
          "--config.file=/etc/prometheus/prometheus.yml",
         ]
        volumes = [
          "local/prometheus_rules.yml:/etc/prometheus/prometheus_rules.yml",
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
          "${meta.cluster_volumes}/prometheus:/prometheus",
        ]
        port_map {
          http = 9090
        }
      }
      resources {
        memory = {{OPTIONS.prometheus_memory_limit}}
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
          path     = "/prometheus/-/healthy"
          interval = "4s"
          timeout  = "2s"
        }
      }
    }
  }
}
