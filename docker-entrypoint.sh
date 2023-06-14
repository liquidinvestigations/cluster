#!/bin/bash -ex

echo "Running in $PWD"

python3 cluster.py configure-network

# exec sudo -nHu vagrant DOCKER_BIN=$DOCKER_BIN python3 ./cluster.py supervisord

export DOCKER_BIN=$DOCKER_BIN
exec python3 ./cluster.py supervisord
