# Nomad Jobs

We've included Nomad jobs for the following:

System jobs run on all nodes. We have the following:

* `dnsmasq` -- DNS server on port 53. Forwards requests like `prometheus.service.consul`
  to the local Consul server, and uses the container's resolv.conf to reply to
  all other requests. This allows all jobs to set the `dns_servers` Docker
  config to the node IP.
* `fabio` -- HTTP load balancer. Used to forward apps to `:9990/$APP_NAME`. Set
  a Consul service tag like `fabio-/something` and it will forward traffic from
  `:9990/something` to that service.
* `telegraf` -- collects stats from the system, Consul and Nomad. Requires `influxdb`

We also run some jobs as services:

* `influxdb` -- service that stores data from telegraf
* `prometheus` -- collects metrics from Nomad
* `grafana` -- displays dashboards with data from Prometheus and Influxdb
* `registry` -- local registry to cache docker images


The `./cluster.py run-jobs` command will trigger the deployment of the files in
`./etc/*.nomad`. This command is automatically run by the `start` command.

To start some of these jobs, set:

```ini
[cluster]
run_jobs = fabio,grafana,prometheus,dnsmasq
```
