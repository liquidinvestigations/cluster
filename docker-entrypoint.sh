#!/bin/bash -ex

python3 cluster.py configure-network
exec python3 ./cluster.py supervisord
