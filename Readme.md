# Cluster - spin up Consul + Vault + Nomad + friends

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

## Quick Start (Linux)

Have `Docker` up and running. You can use
[`get.docker.com`](https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-using-the-convenience-script).

Clone this repository. If using an older version of this repository, `chown`
everything back from `root:` to your current user. Then:

```bash
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

In case of panic, `docker stop cluster` will make it all go away.

## Usage

`./cluster.py install` shells out to `curl` and `unzip` to get binaries for Nomad, Consul
and Vault in the `bin` directory. The Docker image comes with the binaries unpacked.
You can override the versions to be downloaded with the `version` config under
`[nomad]`, `[consul]` and `[vault]`.

After installing, the `./cluster.py configure` command uses Jinja2 to render
all templates from `./templates` to `./etc` according to the `cluster.ini`
file.

The `./cluster.py supervisord` command starts the `supervisor` daemon, which in
turn will run the `./cluster.py start` command. The `start` command will start,
configure and wait for Consul, Vault, Nomad and the system services.

### One Docker Container

Consul, Vault and Nomad can run in one Docker container with host networking
mode with these settings:

```bash
docker run --detach \
  --name cluster \
  --restart always \
  --privileged \
  --net host \
  --env USERID=123 \
  --env GROUPID=456 \
  --env DOCKERGROUPID=789 \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume "$PWD:$PWD" \
  --workdir "$PWD" \
  liquidinvestigations/cluster
```

You need to provide `cluster.ini` (there is one in `examples/`) and UID/GIDs
for the user that's running the container. Of course, the user needs to be in
the `docker` group, and the GID of that group should be set as the env `DOCKERGROUPID`.

The volume path `./var` has to be the same both inside and outside the Docker
container. This is because both Nomad running inside the container and the
host dockerd access the data directory using the path inside the container.

Example usage: [ci/test-docker.sh](ci/test-docker.sh)

#### Options using [bin/docker.sh](bin/docker.sh)

You can use these additional options to modify the docker based startup procedure as used in the Quick Start section above:

* `--name` container name (default: cluster)
* `--image` image (default: liquidinvestigations/cluster)
* `--rm` remove docker container first (default: don't remove container)
* `--pull` pull image

### Installation Guide

The services can run as a user-run `supervisor` that has been installed with
`pipenv install`.

This guide assumes a recent Debian/Ubuntu installation with Python 3.6+ and `pipenv` installed.

* Install dependencies:

    ```bash
    sudo apt update
    sudo apt install python3-pip python3-venv git curl unzip dnsutils iptables
    pip3 install pipenv
    pipenv install
    pipenv shell
    ```

* Download Consul, Vault and Nomad and install their binaries:

    ```bash
    ./cluster.py install
    sudo setcap cap_ipc_lock=+ep bin/vault  # or disable mlock, see below
    ```

* Create a configuration file called `cluster.ini`:

    ```bash
    cp examples/cluster.ini .
    vim cluster.ini
    ```

* Set up the network:

    ```bash
    sudo pipenv run ./cluster.py configure-network
    ```

* Run `supervisor` in the background:

    ```bash
    ./cluster.py supervisord -d
    ```

* Wait for everything to be up and running:

    ```bash
    ./cluster.py wait
    ```

  The `./cluster.py wait` command will poll service health checks until
  everything is running. This can also be used in CI before running the tests.

* Control and monitor the daemons. Some examples:

    ```bash
    ./cluster.py supervisorctl -- start   consul
    ./cluster.py supervisorctl -- stop    nomad
    ./cluster.py supervisorctl -- restart vault
    ./cluster.py supervisorctl -- tail -f start
    ```

* Stop everything: `./cluster.py stop`. This will drain the Nomad node if
  configuration enables that. It will also stop supervisor with a `SIGQUIT`.
  This is triggered by `SIGTERM` and therefore by `docker stop`.

* To run the daemons in the foreground: `./cluster.py runserver <consul|vault|nomad>`

Example usage: [ci/test-host.sh](ci/test-host.sh)

### Installation on macOS

The macOS setup is experimental and there is no automated pipeline testing it.

Docker for Mac runs containers on a Linux virtual machine and does not support
host networking. If we bind everything on a single address like we do in the
Linux setup, then services running inside the Docker for Mac VM won't be able
to to route to services running on the host with the same IP address.

To fix this, we're configuring two local bridges:

* `bridge1` with address `10.66.60.1/32` - for the agents (Nomad, Consul and Vault)
* `bridge2` with address `10.66.60.2/32` - for the services (everything Nomad runs with Docker)

The installation is as follows:

* Install Docker for Mac
* Use Homebrew to install `python3`, `git` and `curl`
* Clone this repository
* Run `sudo ./examples/network-mac.sh`
* Set up `cluster.ini` starting from `./examples/cluster-mac.ini`
* Follow the [Installation Guide](#installation-guide) starting from the `supervisord` step.

## Vault Configuration

Vault requires initialization when installing. It also requires that the Vault
be unsealed after the daemon starts, including after reboot.

In production environments one would use the Vault commands [initialize][] and
[unseal][].

For development, to avoid manually copy/pasting keys, we are using our
`autovault` command after starting the Vault server. On first run, it
initializes the vault, stores the unseal key and root token in
`var/vault-secrets.ini` with permissions `0600`, and unseals it. On subsequent
runs, it uses the same key to unseal the vault, so it's safe to run at boot.

[initialize]: https://www.vaultproject.io/docs/commands/operator/init.html
[unseal]: https://www.vaultproject.io/docs/commands/operator/unseal.html

### Disabling mlock

Disabling mlock is [**not recommended**][disable_mlock], but if you insist, add
this to `cluster.ini`:

```ini
[vault]
disable_mlock = true
```

[disable_mlock]: https://www.vaultproject.io/docs/configuration/#disable_mlock

This flag has no effect on macOS.

## Updating

With the one Docker container setup, you can just:

```bash
./bin/docker.sh --rm --pull
```

When updating an existing installation using `./cluster.py install`, you'll
need to reapply the `mlock` file capabilities for `bin/vault`:

```bash
sudo setcap cap_ipc_lock=+ep bin/vault
```

After that, run `./cluster.py stop` and restart `cluster.py supervisord`.

## Nomad Jobs

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
* `grafana` -- displays dashboards with data from Prometheus and Loki
* `loki` -- collects logs from apps
* `registry` -- local registry to cache docker images

Finally, we have one periodic job:

* `docker-system-prune` -- runs `docker system prune --all --force --volumes` on a single node every hour, since [periodic system jobs](https://github.com/hashicorp/nomad/issues/1944) are not supported by Nomad.

The `./cluster.py run-jobs` command will trigger the deployment of the files in
`./etc/*.nomad`. This command is automatically run by the `start` command.

To start some of these jobs, set:

```ini
[cluster]
run_jobs = fabio,grafana,prometheus,dnsmasq
```

## Multi Host

First, configure a VPN and connect all your nodes to it. You can use [wireguard][] if you.
Use the resulting network interface name and address when configuring

Then, run an instance of this repository on each node be used. A minimal
configuration looks like this:

```ini
[network]
interface = YOUR_VPN_INTERFACE_NAME
address = YOUR_VPN_IP_ADDRESS

[cluster]
node_name = something-unique
bootstrap_expect = 3
retry_join = 10.66.60.1,10.66.60.2,10.66.60.4
```

All nodes should have `run_jobs` set to the same list.

Example set of config files: [ci/configs](ci/configs), see `triple-*.ini`.
**Note**: these configs are using `network.create_bridge = True` because they
are all running on local bridges on a single machine (for testing). You must
not set `network.create_bridge` if you configure the network externally
(e.g. a VPN or LAN).

After launching the services, all but one Vault instance will fail. The one
left running is the primary instance; you can find it in the Consul UI. To make
them all work:

* stop everything
* copy `var/vault-secrets.ini` from the primary to the other nodes
* restart everything

[wireguard]: https://www.wireguard.com/
