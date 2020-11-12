#!/bin/bash -ex

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -yqq git unzip supervisor docker.io python3-pip python3-venv
pip3 install pipenv

echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/es.conf
sysctl --system
adduser vagrant docker
chown vagrant: /opt

mkdir /opt/cluster
cd /opt/cluster
tar xzf /opt/cluster.tar.gz
cp ci/vm-cluster.ini .

chown -R vagrant: .
./bin/docker.sh
docker exec cluster ./cluster.py wait
docker stop -t 90 cluster
docker ps

echo "Provision done!"
