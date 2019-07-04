#!/bin/bash -ex

cd /opt/cluster

sudo ./examples/network.sh
ip a

until docker version; do sleep 1; done

ls -al
sudo chown -R vagrant: .

./examples/docker.sh --rm
docker exec cluster ./cluster.py wait
