#!/bin/bash -ex


if [ -z "${NOMAD_CLIENT_INTERFACE}" ]; then
  export NOMAD_CLIENT_INTERFACE=liquid-bridge
fi

docker run --detach --restart always \
  --name cluster \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume /opt/cluster/var:/opt/cluster/var \
  --volume /opt/cluster/etc:/opt/cluster/etc \
  --volume /opt/cluster/cluster.ini:/opt/cluster/cluster.ini \
  --privileged \
  --net host \
  --env NOMAD_CLIENT_INTERFACE=$NOMAD_CLIENT_INTERFACE \
  liquidinvestigations/cluster
