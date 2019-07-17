#!/bin/bash -e

cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

rmdocker=''
pulldocker=''
name=cluster
image=liquidinvestigations/cluster
while [[ $# -gt 0 ]]; do
  arg=$1
  shift
  case "$arg" in
    "--rm") rmdocker=1 ;;
    "--pull") pulldocker=1 ;;
    "--name") name=$1; shift ;;
    "--image") image=$1; shift ;;
    *) echo "Unknown option $arg" >&2; exit 1
  esac
done

if [ ! -z $pulldocker ]; then
  docker pull $image
fi

if [ ! -z $rmdocker ]; then (
  container=$(docker ps -f name=$name -aq)
  if [ ! -z $container ]; then (
    set -x
    docker stop $container
    docker rm $container
  ) fi
) fi

USERNAME="$(whoami)"
if ! getent group docker | grep -q $(whoami); then
  echo "The current user $USERNAME is not part of the docker group"
  exit 1
fi
USERID="$(id -u $USERNAME)"
GROUPID="$(id -g $USERNAME)"
DOCKERGROUPID="$(getent group docker | cut -d: -f3)"

set -x
docker run --detach \
  --restart always \
  --init \
  --name $name \
  --env USERID=$USERID \
  --env GROUPID=$GROUPID \
  --env DOCKERGROUPID=$DOCKERGROUPID \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume "$PWD:$PWD" \
  --workdir "$PWD" \
  --privileged \
  --net host \
  $image
