#!/bin/bash -e

## Run dockerd with the following options:
# /usr/bin/dockerd -H fd:// --insecure-registry 10.66.60.1:6665 --registry-mirror http://10.66.60.1:6665 --registry-mirror https://registry-1.docker.io

HERE=$(realpath "$(dirname "$(dirname "$0")")")

docker run --detach \
  --restart always \
  --name registry \
  --volume $HERE/registry-config.yml:/etc/docker/registry/config.yml \
  --volume $HERE/../var/registry:/var/lib/registry \
  --publish 6665:5000 \
  registry:2
