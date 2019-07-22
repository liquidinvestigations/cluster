#!/bin/bash -e

# Run this script to start a local registry, then install
# examples/registry-systemd-override.conf to
# /etc/systemd/system/docker.service.d/override.conf, and restart docker:
# sudo systemctl daemon-reload && sudo systemctl restart docker

cd "$( dirname "${BASH_SOURCE[0]}" )"/..

docker run --detach \
  --restart always \
  --name registry \
  --volume $(pwd)/examples/registry-config.yml:/etc/docker/registry/config.yml \
  --volume $(pwd)/var/registry:/var/lib/registry \
  --publish 6665:5000 \
  registry:2
