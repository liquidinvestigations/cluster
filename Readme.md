# Cluster - spin up a Consul + Vault + Nomad cluster

This script installs and configures [consul][], [vault][] and [nomad][]. It's
designed to be easy to use on a fresh Linux machine, therefore it's somewhat
opinionated.

It will install everything in subfolders of the repository:

* `./bin` - Consul, Vault and Nomad binaries
* `./var` - cluster state and temporary files
* `./etc` - configuration files

The script generates a [supervisord][] configuration file in
`./etc/supervisor-cluster.conf` that can be easily symlinked to e.g.
`/etc/supervisor/conf.d/cluster.conf`.

[consul]: https://www.consul.io/
[vault]: https://www.vaultproject.io/
[nomad]: https://www.nomadproject.io/
[supervisord]: http://supervisord.org/

# Installation

## Installation on Linux

This guide assumes a recent Debian/Ubuntu installation.

* Install dependencies:

    ```shell
    sudo apt update
    sudo apt install python3 git supervisor curl unzip
    ```

* Download Consul, Vault and Nomad and install their binaries:

    ```shell
    ./cluster.py install
    sudo setcap cap_ipc_lock=+ep bin/vault  # or disable mlock, see below
    ```

* Create a configuration file called `cluster.ini`:

    ```shell
    cp examples/cluster.ini .
    vim cluster.ini
    ```

* Set up the network. You can use our example configuration in `examples/network.sh`.

* Generate configuration files for Consul, Vault and Nomad and a `supervisord`
  configuration for the daemons:

    ```shell
    ./cluster.py configure
    sudo ln -s $(pwd)/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf
    sudo supervisorctl update
    ```

* To control the daemons, run `sudo supervisorctl <start|stop|restart> cluster:<consul|vault|nomad>`

* To run the daemons in the foreground: `./cluster.py runserver <consul|vault|nomad>`

## Installation on Mac OS

* Install dependencies

    Install `brew` (see [brew]: https://brew.sh)

    ```shell
    brew install python git supervisor curl
    sudo chown root:wheel /usr/local/Cellar/supervisor/$(brew list supervisor | tail -1 | cut -f 6 -d /)/homebrew.mxcl.supervisor.plist
    sudo ln -s /usr/local/opt/supervisor/homebrew.mxcl.supervisor.plist /Library/LaunchDaemons
    sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.supervisor.plist
    ```

* Download Consul, Vault and Nomad and install their binaries:

    ```shell
    ./cluster.py install
    sudo setcap cap_ipc_lock=+ep bin/vault  # or disable mlock, see below
    ```

* Create a configuration file called `cluster.ini`:

    ```shell
    cp examples/cluster.ini .
    vim cluster.ini
    ```

* Set up the network. You can use our example configuration in `examples/network-mac.sh`

* Generate configuration files for Consul, Vault and Nomad and a `supervisord`
  configuration for the daemons:

    ```shell
    ./cluster.py configure
    mkdir /usr/local/etc/supervisor.d
    sudo ln -s $(pwd)/etc/supervisor-cluster.conf /usr/local/etc/supervisor.d/cluster.ini
    sudo supervisorctl update
    ```

* To control the daemons, run `sudo supervisorctl <start|stop|restart> cluster:<consul|vault|nomad>`

* To run the daemons in the foreground: `./cluster.py runserver <consul|vault|nomad>`


## Vault

Vault requires initialization when installing. It also requires that the Vault
be unsealed after the daemon starts, including after reboot.

For production environments, use the Vault commands [initialize][] and
[unseal][].

For development, to avoid manually copy/pasting keys, you can use the
`autovault` command. On first run, it initializes the vault, stores the unseal
key and root token in `var/vault-secrets.ini` with permissions `0600`, and
unseals it. On subsequent runs, it uses the same key to unseal the vault, so
it's safe to run at boot. Be sure to restart the Nomad daemon after running
`autovault` so that Nomad picks up the new root token.

```shell
./cluster.py autovault
sudo supervisorctl restart cluster:nomad
```

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

#### Updating

When updating an existing installation using `./cluster.py install`, you'll
need to reapply the `mlock` file capabilities for `bin/vault`:

```shell
sudo setcap cap_ipc_lock=+ep bin/vault
```

## Docker

The whole set of services can run in Docker.

First fill out `liquid.ini` normally. Then set the desired network interface and run this script:

```shell
export NOMAD_CLIENT_INTERFACE=eth6
./examples/docker.sh
```

Then go to consul (port 8500 on the network interface you chose) and wait for
the health check lights to turn green.


## Multi Host

Run an instance of each service (or a docker container) on each host to be used. Set the following configuration flags on each one:

```ini
[cluster]
bootstrap_expect = 3
retry_join = 10.66.60.1,10.66.60.2,10.66.60.4
```

After launching the services, all but one Vault instance will fail. The one left running is the primary instance; you can find it in the Consul UI. To make them all work, copy the keys from the leader's `var/vault-secrets.ini` file to the other nodes.
