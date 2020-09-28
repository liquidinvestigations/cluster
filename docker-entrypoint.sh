#!/bin/bash -ex

echo "Running in $PWD"
ls -alh

echo "Changing permissions..."
if [ -c /dev/kvm ]; then
  chown root: /dev/kvm
fi

sysctl vm.max_map_count=262144
sysctl net.bridge.bridge-nf-call-arptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
sysctl net.bridge.bridge-nf-call-iptables=1

python3 cluster.py configure-network

DOCKER_BIN=$DOCKER_BIN python3 ./cluster.py supervisord
