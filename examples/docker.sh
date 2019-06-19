#!/bin/bash -e

HERE=$(realpath "$(dirname "$(dirname "$0")")")

rmdocker=''
for arg in "$@"; do
  shift
  case "$arg" in
    "--rm") rmdocker=1 ;;
    *) echo "Unknown option $arg" >&2; exit 1
  esac
done

if [ ! -z $rmdocker ]; then (
  container=$(docker ps -f name=cluster -aq)
  if [ ! -z $container ]; then (
    set -x
    docker stop $container
    docker rm $container
  ) fi
) fi

set -x
docker run --detach \
  --restart always \
  --name cluster \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume $HERE/var:/opt/cluster/var \
  --volume $HERE/etc:/opt/cluster/etc \
  --volume $HERE/cluster.ini:/opt/cluster/cluster.ini:ro \
  --volume $HERE/cluster.py:/opt/cluster/cluster.py \
  --volume $HERE/templates:/opt/cluster/templates \
  --privileged \
  --net host \
  liquidinvestigations/cluster
