#!/bin/bash -ex

cd /opt/cluster

./examples/network.sh
ip a

until docker version; do sleep 1; done

./examples/docker.sh --rm
docker exec cluster ./cluster.py wait
