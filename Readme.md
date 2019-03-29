# Cluster - spin up a Nomad + Consul cluster

This script installs and configures nomad and consul. It's designed to be easy
to use on a fresh Linux machine, therefore it's somewhat opinionated.

It will install everything in subfolders of the repository:
* `./bin` - Consul and Nomad binaries
* `./var` - cluster state and temporary files
* `./etc` - configuration files

The script generates a [supervisord][] configuration file in
`./etc/supervisor-cluster.conf` that can be easily symlinked to e.g.
`/etc/supervisor/conf.d/cluster.conf`.

[supervisord]: http://supervisord.org/


## HowTo (Debian, Ubuntu)

```shell
CLUSTER_HOME=/opt/cluster

sudo apt update
sudo apt install python3 git supervisor

cd /tmp
git clone https://github.com/liquidinvestigations/cluster
sudo mv cluster "$CLUSTER_HOME"

cd "$CLUSTER_HOME"
./cluster.py install
./cluster.py configure

cd /etc/supervisor/conf.d
sudo ln -s "$CLUSTER_HOME"/etc/supervisor-cluster.conf cluster.conf

sudo supervisorctl update
```


## Usage

* `./cluster.py install` - Download Consul and Nomad and install their
  binaries.

* `./cluster.py configure` - Generate configuration files for Consul and Nomad
  and a `supervisord` configuration for the daemons.
