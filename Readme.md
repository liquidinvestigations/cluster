# Cluster - spin up Consul + Vault + Nomad + friends

This script installs and configures [Consul][], [Vault][] and [Nomad][]. After
those are up, we're running [dnsmasq][] to forward Consul's DNS, [Prometheus][]
to collect Nomad stats and [Grafana][] to display them in a nice dashboard.
It's designed to be easy to use on a fresh Linux machine, therefore it's
somewhat opinionated.

It will install everything in subfolders of the repository:

* `./bin` - Consul, Vault and Nomad binaries
* `./var` - cluster state and temporary files
* `./etc` - configuration files

The script generates a [supervisord][] configuration file in
`./etc/supervisord.conf` that should be run with your

[consul]: https://www.consul.io/
[vault]: https://www.vaultproject.io/
[nomad]: https://www.nomadproject.io/
[supervisord]: http://supervisord.org/
[dnsmasq]: http://www.thekelleys.org.uk/dnsmasq/doc.html
[Prometheus]: http://prometheus.io/
[Grafana]: https://grafana.com/

## Quick Start (Linux)

Have `Docker` up and running.


The first script, `examples/network.sh`, will create a local network bridge
called `liquid-bridge` with IP address `10.66.60.1`.
It will also set up `iptables` rules to forward ports 80 and 443 from your
outgoing interface to the local bridge IP address.


Clone this repository, then:


```bash
sudo ./examples/network.sh
cp examples/cluster.ini .
./examples/docker.sh
docker exec cluster ./cluster.py supervisorctl -- tail -f start
```

Wait a minute and visit:

- http://10.66.60.1:8500 - Consul
- http://10.66.60.1:4646 - Nomad
- http://10.66.60.1:8200 - Vault
- http://10.66.60.1:9990/fabio
- http://10.66.60.1:9990/prometheus
- http://10.66.60.1:9990/grafana
- http://10.66.60.1:9990/alertmanager

In case of panic, `docker stop cluster` will make it all go away.


## How it works

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

Consul, Vault and Nomad can run in one Docker container with host networking mode.

```bash
docker run --detach \
  --name cluster \
  --restart always \
  --privileged \
  --net host \
  --user 1066:601 \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume $HERE/cluster.ini:/opt/cluster/cluster.ini:ro \
  liquidinvestigations/cluster
```

You need to provide `cluster.ini` (there is one in `examples/`) and optionally
mount docker volumes for `/opt/cluster/etc` and `/opt/cluster/var`.


### Installation Guide

The services can run as a user-run `supervisor` that has been installed with
`pipenv install`.

This guide assumes a recent Debian/Ubuntu installation with Python 3.6+ and `pipenv` installed.
* Install dependencies:

    ```bash
    sudo apt update
    sudo apt install python3 git curl unzip
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

* Set up the network. You can use our example configuration in `examples/network.sh`.

* Run `supervisor` in the background:

    ```bash
    ./cluster.py supervisord -d
    ```

* To control the daemons, run `./cluster.py supervisorctl <start|stop|restart> <consul|vault|nomad>`

* Stop everything: `./cluster.py stop`. This will drain the Nomad node and kill
  supervisor. This gets triggered by `SIGTERM` and therefore to `docker stop`.

* To run the daemons in the foreground: `./cluster.py runserver <consul|vault|nomad>`


### Installation on Mac OS

* Use [Homebrew][] to install `python3`, `git` and `curl`
* Clone this repository
* Install Docker for Mac
* Run `sudo ./examples/network-mac.sh`
* Follow the [Installation Guide](#installation-guide)
  taking care to edit the nomad interface name in `cluster.ini`.

You may encounter some limitations:

* Fabio may not be able to connect to Consul.


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


## Updating

When updating an existing installation using `./cluster.py install`, you'll
need to reapply the `mlock` file capabilities for `bin/vault`:

```bash
sudo setcap cap_ipc_lock=+ep bin/vault
```

After that, run `./cluster.py stop` and restart `cluster.py supervisord`.

---


With the one Docker container setup, you can just:

```bash
./examples/docker.sh --rm --pull
```


## Multi Host

Run an instance of each service (or a docker container) on each host to be
used. Set the following configuration flags on each one:

```ini
[cluster]
bootstrap_expect = 3
retry_join = 10.66.60.1,10.66.60.2,10.66.60.4
```

After launching the services, all but one Vault instance will fail. The one
left running is the primary instance; you can find it in the Consul UI. To make
them all work, copy the keys from the leader's `var/vault-secrets.ini` file to
the other nodes.
