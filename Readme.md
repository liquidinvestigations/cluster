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
sudo apt update
sudo apt install python3 git supervisor curl

./cluster.py install
./cluster.py configure

sudo ln -s $(pwd)/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf
sudo supervisorctl update
```


## Usage

* `./cluster.py install` - Download Consul and Nomad and install their
  binaries.

* `./cluster.py configure` - Generate configuration files for Consul and Nomad
  and a `supervisord` configuration for the daemons.

* `sudo supervisorctl [start|stop|restart] cluster:` - Start, stop and restart
  Consul and Nomad as Supervisor programs.

* `./cluster.py runserver consul` and `./cluster.py runserver nomad` - Start
  Consul and Nomad in the foreground.
