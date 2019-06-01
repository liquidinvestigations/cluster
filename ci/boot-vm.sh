#!/bin/bash -ex

cd /opt/cluster

./examples/network.sh
ip a

until docker version; do sleep 3; done

docker rm -f cluster || true
./examples/docker.sh
until docker exec cluster /opt/cluster/cluster.py autovault; do sleep 10; done
