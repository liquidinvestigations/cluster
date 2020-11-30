#!/bin/bash -ex

cd /opt/cluster

until docker version; do sleep 1; done

ls -al
sudo chown -R vagrant: .

./bin/docker.sh --rm --image liquidinvestigations/cluster:master
docker exec cluster ./cluster.py wait

echo "waiting for shutdown..."
sleep 3600
sudo poweroff -f
