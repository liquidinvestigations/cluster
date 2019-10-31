# Manual Installation

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


### Updating

When updating an existing installation using `./cluster.py install`, you'll
need to reapply the `mlock` file capabilities for `bin/vault`:

```bash
sudo setcap cap_ipc_lock=+ep bin/vault
```

After that, run `./cluster.py stop` and restart `cluster.py supervisord`.


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
