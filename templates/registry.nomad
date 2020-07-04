job "registry" {
  datacenters = ["dc1"]
  type = "system"
  priority = 90

  group "registry" {
    constraint {
      attribute = "${meta.cluster_volumes}"
      operator = "is_set"
    }

    task "registry" {
      driver = "docker"

      config {
        image = "registry:2"
        volumes = [
          "local/registry-config.yml:/etc/docker/registry/config.yml:ro",
          "${meta.cluster_volumes}/registry:/var/lib/registry",
        ]
        port_map {
          http = 5000
        }
      }

      template {
        destination = "local/registry-config.yml"
        data = <<-EOF
          version: 0.1
          log:
            fields:
              service: registry
          storage:
            cache:
              blobdescriptor: inmemory
            filesystem:
              rootdirectory: /var/lib/registry
          http:
            addr: :5000
            headers:
              X-Content-Type-Options: [nosniff]
          health:
            storagedriver:
              enabled: true
              interval: 10s
              threshold: 3
          proxy:
            remoteurl: https://registry-1.docker.io
          EOF
      }

      resources {
        cpu = 200
        memory = 100
        network {
          mbits = 10
          port "http" {
            static = 9991
          }
        }
      }

      service {
        name = "registry"
        port = "http"
        check {
          name = "http"
          type = "http"
          path = "/"
          interval = "14s"
          timeout  = "12s"
        }
      }
    }
  }
}
