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
      attempts = 4
      interval = "48s"
      delay = "10s"
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
      user = "root"
      config {
        image = "prom/prometheus:v2.19.2"
        args = [
          "--web.route-prefix=/prometheus",
          "--web.external-url=http://${attr.unique.network.ip-address}:9990/prometheus",
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.retention.time=20d",
         ]
        volumes = [
          "local/prometheus_rules.yml:/etc/prometheus/prometheus_rules.yml:ro",
          "local/prometheus.yml:/etc/prometheus/prometheus.yml:ro",
          "${meta.cluster_volumes}/prometheus/2.19.2:/prometheus",
        ]
        port_map {
          http = 9090
        }
        memory_hard_limit = {{OPTIONS.prometheus_memory_limit * 4}}
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
          interval = "14s"
          timeout  = "12s"
        }
      }
    }
  }
}
