job "influxdb" {
  datacenters = ["dc1"]
  type = "service"
  priority = 89

  group "influxdb" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }

    task "influxdb" {
      driver = "docker"
      config {
        image = "influxdb:1.5-alpine"
        dns_servers = ["${attr.unique.network.ip-address}"]
        port_map {
          http = 8086
        }
        volumes = [
          "${meta.cluster_volumes}/influxdb-1.8-tsi1:/var/lib/influxdb",
          "local/telegraf-create-retention.iql:/docker-entrypoint-initdb.d/telegraf-create-retention.iql:ro",
        ]
      }

      env {
        GOMAXPROCS = "4"
        INFLUXDB_DB = "telegraf"
        INFLUXDB_REPORTING_DISABLED = "true"

        INFLUXDB_RETENTION_ENABLED = "true"
        INFLUXDB_RETENTION_CHECK_INTERVAL = "60m0s"

        INFLUXDB_DATA_INDEX_VERSION = "tsi1"
        INFLUXDB_DATA_MAX_INDEX_LOG_FILE_SIZE = "{{int(OPTIONS.influxdb_memory_limit * 0.1)}}m"
        INFLUXDB_DATA_CACHE_MAX_MEMORY_SIZE = "{{int(OPTIONS.influxdb_memory_limit * 0.5)}}m"
        INFLUXDB_DATA_CACHE_SNAPSHOT_MEMORY_SIZE = "{{int(OPTIONS.influxdb_memory_limit * 0.1)}}m"
      }

      resources {
        cpu    = 120
        memory = {{OPTIONS.influxdb_memory_limit}}
        network {
          mbits = 1
          port "http" {}
        }
      }

      template {
        destination = "local/telegraf-create-retention.iql"
        data = <<-EOH
        ALTER RETENTION POLICY "autogen" ON "telegraf" DURATION 16d SHARD DURATION 8h DEFAULT
        EOH
      }

      service {
        name = "influxdb"
        port = "http"
        tags = ["fabio-/influxdb strip=/influxdb"]
        check {
          name     = "http"
          type     = "http"
          path     = "/ping"
          interval = "21s"
          timeout  = "14s"
        }
      }
    }
  }
}
