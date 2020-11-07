job "cluster-fabio" {
  datacenters = ["dc1"]
  type = "system"
  priority = 99

  group "fabio" {
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio:1.5.13-go1.13.4"
        volumes = [
          "local/fabio.properties:/etc/fabio/fabio.properties"
        ]
        port_map {
          ui = 8000
          lb = 9990
          extra1 = 9991
          extra2 = 9992
          extra3 = 9993
          extra4 = 9994
          extra5 = 9995
          extra6 = 9996
          extra7 = 9997
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

        ui.addr = :8000
        ui.color = green
        proxy.addr = :9990
        EOH
      }

      resources {
        cpu    = 200
        memory = 128
        network {
          mbits = 20
          port "lb" { static = 9990 }
          port "extra1" { static = 9991 }
          port "extra2" { static = 9992 }
          port "extra3" { static = 9993 }
          port "extra4" { static = 9994 }
          port "extra5" { static = 9995 }
          port "extra6" { static = 9996 }
          port "extra7" { static = 9997 }
          port "ui" {
          }
        }
      }

      service {
        name = "cluster-fabio"
        port = "lb"
        check {
          name     = "tcp"
          type     = "tcp"
          interval = "14s"
          timeout  = "12s"
        }
      }
      service {
        name = "cluster-fabio-ui"
        port = "ui"
        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "16s"
          timeout  = "13s"
        }
      }
    }
  }
}
