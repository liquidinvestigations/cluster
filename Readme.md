# Cluster - spin up Consul + Vault + Nomad + friends

[![Build Status](https://jenkins.liquiddemo.org/api/badges/liquidinvestigations/cluster/status.svg)](https://jenkins.liquiddemo.org/liquidinvestigations/cluster)

This script installs and configures [Consul][], [Vault][] and [Nomad][]. After
those are up, we're running [dnsmasq][] to forward Consul's DNS, [Prometheus][]
to collect Nomad stats, [Loki][] to collect logs, and [Grafana][] to display
them in a nice dashboard. It also runs a local [Docker registry][] to cache
images. It's designed to be easy to use on a fresh Linux machine, therefore
it's somewhat opinionated.

[consul]: https://www.consul.io/
[vault]: https://www.vaultproject.io/
[nomad]: https://www.nomadproject.io/
[supervisord]: http://supervisord.org/
[dnsmasq]: http://www.thekelleys.org.uk/dnsmasq/doc.html
[Prometheus]: http://prometheus.io/
[Grafana]: https://grafana.com/
[Loki]: https://grafana.com/oss/loki
[Docker registry]: https://docs.docker.com/registry/deploying/

## Quick start

Install and have `Docker` up and running. Follow the instructions at
[`get.docker.com`](https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-using-the-convenience-script).

Clone this repository, then:

```bash
cd /opt/cluster
cp examples/cluster.ini .
./bin/docker.sh
docker exec cluster ./cluster.py supervisorctl -- tail -f start
```

Wait a minute and visit:

* <http://10.66.60.1:8500> - Consul
* <http://10.66.60.1:4646> - Nomad
* <http://10.66.60.1:8200> - Vault

If `fabio` has been enabled in `cluster.ini`, visit:

* <http://10.66.60.1:9990/grafana>

In case of panic or just to stop it, `docker stop cluster` will make it all go away.


## Running a specific version
To run a tagged version (e.g. `v0.7.0`) of cluster:

```shell
git checkout v0.7.0
./bin/docker.sh --image liquidinvestigations/cluster:0.7.0
```


## More documentation
* Installation as a Docker container:
  [docs/Docker-Installation.md](docs/Docker-Installation.md)
* Installation manually on the system:
  [docs/Manual-Installation.md](docs/Manual-Installation.md)
* Vault configuration:
  [docs/Vault.md](docs/Vault.md)
* Running a multi-host cluster:
  [docs/Multi-Host.md](docs/Multi-Host.md)
* Batteries included - bundled Nomad jobs:
  [docs/Nomad-Jobs.md](docs/Nomad-Jobs.md)
