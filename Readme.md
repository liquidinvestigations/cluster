# Cluster - spin up Consul + Vault + Nomad + friends

[![Build Status](https://jenkins.liquiddemo.org/api/badges/liquidinvestigations/cluster/status.svg)](https://jenkins.liquiddemo.org/liquidinvestigations/cluster)

This script installs and configures [Consul][], [Vault][] and [Nomad][]. It uses Docker to package these services, since this is not supported by Hashicorp.

[consul]: https://www.consul.io/
[vault]: https://www.vaultproject.io/
[nomad]: https://www.nomadproject.io/
[supervisord]: http://supervisord.org/

## Quick start

Install and have `Docker` up and running. Follow the instructions at
[`get.docker.com`](https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-using-the-convenience-script).

In case you are using a firewall you may need to allow connections to the IP-adress the liquid bundle is running on. For ufw this can be done with `sudo ufw allow to 10.66.60.1`.

Clone this repository, then:

```bash
cd /opt/cluster

sudo apt install -y nohang  # on CentOS, you can use use "yum"
sudo cp ./examples/nohang.conf /etc/nohang/nohang.conf
sudo systemctl enable nohang.service
sudo systemctl start nohang.service

cp examples/cluster.ini .
./bin/docker.sh
docker exec cluster ./cluster.py supervisorctl -- tail -f start
```

Wait a minute and visit:

* <http://10.66.60.1:8500> - Consul
* <http://10.66.60.1:4646> - Nomad
* <http://10.66.60.1:8200> - Vault

In case of panic or just to stop it, `docker stop cluster` will make it all go away.


## Running a specific version
To run a tagged version (e.g. `v0.9.0`) of cluster:

```shell
git checkout v0.9.0
./bin/docker.sh --image liquidinvestigations/cluster:0.9.0
```


## Running a command inside a task container

Use `cluster.py nomad-exec JOB:TASK COMMAND...` to execute a command inside a
container. `stdin` and `stdout` can be used to exchange data.
The command uses
[`nomad alloc exec`](https://nomadproject.io/docs/commands/alloc/exec/).

## Installing node ##
As a next step you can install `node`, by following these [instructions](https://github.com/liquidinvestigations/node#installation) .


## More documentation
* Installation as a Docker container:
  [docs/Docker-Installation.md](docs/Docker-Installation.md)
* Installation manually on the system:
  [docs/Manual-Installation.md](docs/Manual-Installation.md)
* Vault configuration:
  [docs/Vault.md](docs/Vault.md)
* Running a multi-host cluster:
  [docs/Multi-Host.md](docs/Multi-Host.md)
