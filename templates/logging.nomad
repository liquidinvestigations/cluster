job "logging" {
  datacenters = ["dc1"]
  type = "service"
  priority = 100

  group "elasticsearch" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }

    network {
      mode = "bridge"
    }

    service {
      name = "logging-elasticsearch"
      port = 9200
      connect {
        sidecar_service {}
      }
      check {
        name     = "http"
        type     = "http"
        path     = "/"
        interval = "8s"
        timeout  = "4s"
      }
    }

    task "elasticsearch" {
      config {
        image = "docker.elastic.co/elasticsearch/elasticsearch:7.4"
        dns_servers = ["${attr.unique.network.ip-address}"]
        volumes = [
          "${meta.cluster_volumes}/elasticsearch:/var/lib/elasticsearch/data",
        ]
      }

      env {
        ES_JAVA_OPTS = "-Xms500m -Xmx500m -XX:+UnlockDiagnosticVMOptions"
      }

      resources {
        cpu    = 120
        memory = 600
        network {
          mbits = 1
          port "http" {}
        }
      }
    }
  }

  group "kibana" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }
  }

  group "fluentd" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }

    task "fluentd" {
      driver = "docker"
      config {
        image = "fluent/fluentd:v1.7-1"
        dns_servers = ["${attr.unique.network.ip-address}"]
        port_map {
          http = 24224
        }
        volumes = [
          "${meta.cluster_volumes}/fluentd:/var/lib/influxdb",
        ]
      }

      env {
        INFLUXDB_DB = "telegraf"
      }

      resources {
        cpu    = 120
        memory = {{OPTIONS.influxdb_memory_limit}}
        network {
          mbits = 1
          port "http" {}
        }
      }

      service {
        name = "influxdb"
        port = "http"
        tags = ["fabio-/fluentd strip=/fluentd"]
        check {
          name     = "http"
          type     = "http"
          path     = "/ping"
          interval = "8s"
          timeout  = "4s"
        }
      }
    }
  }
}
