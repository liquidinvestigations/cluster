#!/bin/bash -e

## Run dockerd with the following options:
# /usr/bin/dockerd -H fd:// --insecure-registry 10.66.60.1:6665 --registry-mirror http://10.66.60.1:6665 --registry-mirror https://registry-1.docker.io

cd "$( dirname "${BASH_SOURCE[0]}" )"/..

docker run --detach \
  --restart always \
  --name registry \
  --volume ./examples/registry-config.yml:/etc/docker/registry/config.yml \
  --volume ./var/registry:/var/lib/registry \
  --publish 6665:5000 \
  registry:2
