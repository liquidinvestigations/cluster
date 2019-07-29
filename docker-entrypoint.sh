#!/bin/bash -ex

python3 cluster.py configure-network
exec DOCKER_BIN=$DOCKER_BIN python3 ./cluster.py supervisord
