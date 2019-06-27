job "dnsmasq" {
  datacenters = ["dc1"]
  type = "system"

  group "dnsmasq" {
    restart {
      attempts = 10
      interval = "5m"
      delay = "10s"
      mode = "delay"
    }

    task "dnsmasq" {
      driver = "docker"
      config {
        image = "andyshinn/dnsmasq:2.78"
        port_map {
          dns = 53
        }
        args = ["--log-facility=-", "--conf-file=/etc/dnsmasq.conf"]
        cap_add = ["NET_ADMIN"]
        volumes = [
          "local/dnsmasq.conf:/etc/dnsmasq.conf"
        ]
      }

      template {
        data = <<-EOF
        bind-interfaces
        #no-resolv
        #no-poll
        #no-hosts
        #log-dhcp
        #log-queries
        server=/consul/{{OPTIONS.consul_address}}#8600
        #server=1.2.3.4
        #server=208.67.222.222
        #server=8.8.8.8
        EOF

        destination = "local/dnsmasq.conf"
      }

      resources {
        cpu    = 50
        memory = 50
        network {
          mbits = 10
          port "dns" {
            static = 53
          }
        }
      }

      service {
        name = "dnsmasq"
        port = "dns"
      }
    }
  }
}

