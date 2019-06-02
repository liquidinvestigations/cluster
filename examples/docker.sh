#!/bin/bash -ex

HERE=$(realpath "$(dirname "$(dirname "$0")")")


docker run --detach \
  --restart always \
  --name cluster \
  --privileged \
  --tmpfs /run \
  --volume /var/run/docker.sock:/var/run/docker.sock:ro \
  --volume $HERE/var:/opt/cluster/var \
  --volume $HERE/etc:/opt/cluster/etc \
  --volume $HERE/charts:/opt/cluster/charts \
  --volume $HERE/cluster.ini:/opt/cluster/cluster.ini:ro \
  --volume $HERE/cluster.py:/opt/cluster/cluster.py \
  --net host \
  liquidinvestigations/cluster
