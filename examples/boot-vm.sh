#!/bin/bash -ex

cd /opt/cluster
./examples/network.sh
docker rm -f cluster || true
./examples/docker.sh
until docker exec cluster /opt/cluster/cluster.py autovault; do sleep 10; done
