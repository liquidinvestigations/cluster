job "docker-system-prune" {
  datacenters = ["dc1"]
  type = "batch"
  priority = 99

  periodic {
    cron  = "@hourly"
    prohibit_overlap = true
  }

  group "prune" {
    task "prune" {
      driver = "docker"
      config {
        image = "docker:19"
        volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
        args = ["system", "prune", "--all", "--volumes", "--force"]
      }
      resources {
        cpu    = 200
        memory = 128
        network {
          mbits = 1
        }
      }
    }
  }
}
