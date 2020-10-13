#!/bin/bash -ex

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -yqq git unzip python3-pip python3-venv supervisor curl wget iptables sudo docker.io
pip3 install --system pipenv
systemctl enable supervisor

echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/es.conf
sysctl --system

echo "vagrant ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
adduser vagrant docker

mkdir /opt/cluster
cd /opt/cluster
tar xzf /opt/cluster.tar.gz

cp examples/cluster.ini .
./install
systemctl restart supervisor
./cluster wait

echo "Provision done!"
