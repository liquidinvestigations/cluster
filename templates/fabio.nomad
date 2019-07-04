job "fabio" {
  datacenters = ["dc1"]
  type = "system"

  group "fabio" {
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio:1.5.11-go1.11.5"
        network_mode = "host"
        volumes = [
          "local/fabio.properties:/etc/fabio/fabio.properties"
        ]
      }
      template {
        destination = "local/fabio.properties"
        data = <<-EOH
        registry.backend = consul
        registry.consul.addr = {{OPTIONS.consul_address}}:8500
        registry.consul.checksRequired = all
        registry.consul.tagprefix = fabio-
        registry.consul.register.tags = fabio-/fabio
        ui.addr = ${NOMAD_ADDR_ui}
        registry.consul.register.addr = ${NOMAD_ADDR_ui}
        proxy.addr = ${NOMAD_ADDR_lb}
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
          }
        }
      }
    }
  }
}
