# Cluster - spin up Consul + Vault + Nomad + friends

[![Build Status](https://jenkins.liquiddemo.org/api/badges/liquidinvestigations/cluster/status.svg)](https://jenkins.liquiddemo.org/liquidinvestigations/cluster)

This script installs and configures [Consul][], [Vault][] and [Nomad][]. After
those are up, we're running [dnsmasq][] to forward Consul's DNS, [Prometheus][]
to collect Nomad stats, and [Grafana][] to display
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
[Docker registry]: https://docs.docker.com/registry/deploying/

## Installation

1. Install Docker from https://get.docker.com.

2. Install the following packages on your machine from your package manager (list is for Debian):

- sudo
- git
- unzip
- python3-pip
- python3-venv
- supervisor
- curl
- wget
- iptables

3. Then, install `pipenv` system-wide:

```bash
sudo pip3 install --system pipenv
```


4. Navigate to the root directory and run:

```bash
sudo systemctl enable supervisor
sudo systemctl stop supervisor

# Read and edit this configuration file:
cp examples/cluster.ini .
vim ./cluster.ini

# Download additional binaries from the internet.
# This also configures the system-wide supervisor.
sudo ./install

sudo systemctl start supervisor
```

5. Use the following to monitor progress:

```bash
sudo ./ctl status
sudo ./ctl tail -f start
sudo ./ctl tail nomad
```

Here's how the `status` result should look like:
```bash
sudo ./ctl

supervisor> status
autovault                        EXITED    Oct 10 05:34 PM
consul                           RUNNING   pid 101522, uptime 0:16:57
nomad                            RUNNING   pid 101942, uptime 0:16:15
start                            EXITED    Oct 10 05:36 PM
vault                            RUNNING   pid 101602, uptime 0:16:45
supervisor>
```

Wait a minute and visit:

* <http://10.66.60.1:8500> - Consul
* <http://10.66.60.1:4646> - Nomad
* <http://10.66.60.1:8200> - Vault

If `fabio` has been enabled in `cluster.ini`, visit:

* <http://10.66.60.1:9990/grafana>

In case of panic or just to stop it, `sudo ./stop` will make it all go away.

After it's stopped, you can re-start it with `sudo ./restart`.


## Update to a specific version

To run a tagged version (`v0.13.0` or later) of cluster:

```shell
# Stop any existing installation and verify everything is dead:
sudo ./stop
docker ps

# Checkout the desired version:
git checkout v0.13.0

# Reconcile your config with `examples/cluster.ini`:
vim -O cluster.ini examples/cluster.ini

# Check out and install the desired version:
sudo ./install

# If you changed the networking config, reboot the machine:
sudo reboot

# If not, try just running the `restart` command:
sudo ./restart
```

### Updating from versions <0.13

- Completely stop the system: `docker stop -t 300 cluster; docker stop $(docker ps -q)`
- Delete the `cluster` container: `docker rm -f cluster`
- Checkout the new version
- Copy over and configure the [supervisor] config section from `examples/cluster.ini`
- Continue with the installation instructions above. The system should resume from where it left off.


## Running a command inside a task container

Use `./nomad-exec JOB:TASK COMMAND...` to execute a command inside a
container. `stdin` and `stdout` can be used to exchange data.
The command uses
[`nomad alloc exec`](https://nomadproject.io/docs/commands/alloc/exec/).


## More documentation
* Vault configuration:
  [docs/Vault.md](docs/Vault.md)
* Running a multi-host cluster:
  [docs/Multi-Host.md](docs/Multi-Host.md)
* Batteries included - bundled Nomad jobs:
  [docs/Nomad-Jobs.md](docs/Nomad-Jobs.md)
