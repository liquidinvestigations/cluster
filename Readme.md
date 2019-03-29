# Cluster - spin up a Nomad + Consul cluster

This script installs nomad and consul, configures them, and generates a
[supervisord][] configuration file for them. It's designed to be easy to use on
a fresh Linux machine, so it's somewhat opinionated.


## Setup (Debian, Ubuntu)

```
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
