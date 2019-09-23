job "cluster-fabio" {
  datacenters = ["dc1"]
  type = "system"
  priority = 99

  group "fabio" {
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio:1.5.11-go1.11.5"
        volumes = [
          "local/fabio.properties:/etc/fabio/fabio.properties"
        ]
        port_map {
          ui = 9991
          lb = 9990
        }
      }
      template {
        destination = "local/fabio.properties"
        data = <<-EOH
        registry.backend = consul
        registry.consul.addr = {{OPTIONS.consul_address}}:8500
        registry.consul.checksRequired = all
        registry.consul.tagprefix = fabio-
        registry.consul.kvpath = /cluster/fabio
        registry.consul.register.enabled = false

        ui.addr = :9991
        ui.color = green
        proxy.addr = :9990
        EOH
      }

      resources {
        cpu    = 200
        memory = 128
        network {
          mbits = 20
          port "lb" {
            static = 9990
          }
          port "ui" {
            static = 9991
          }
        }
      }

      service {
        name = "cluster-fabio"
        port = "lb"
        check {
          name     = "tcp"
          type     = "tcp"
          interval = "4s"
          timeout  = "2s"
        }
      }
      service {
        name = "cluster-fabio-ui"
        port = "ui"
        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "6s"
          timeout  = "3s"
        }
      }
    }
  }
}
