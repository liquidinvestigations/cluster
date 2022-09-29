#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"/..

rmdocker=''
pulldocker=''
nowait=''
no_nohang=''
name=cluster
image=liquidinvestigations/cluster
while [[ $# -gt 0 ]]; do
  arg=$1
  shift
  case "$arg" in
    "--rm") rmdocker=1 ;;
    "--pull") pulldocker=1 ;;
    "--nowait") nowait=1 ;;
    "--no-nohang") no_nohang=1; ;;
    "--name") name=$1; shift ;;
    "--image") image=$1; shift ;;
    *) echo "Unknown option $arg" >&2; exit 1
  esac
done

if [ -z $no_nohang ]; then
  # check if nohang installed; if it's not, then prompt all commands
  if ! ( /usr/sbin/nohang --check --config /etc/nohang/nohang.conf &> /dev/null ); then
    echo "'nohang' service not installed. Please install and enable it with the provided config file."
    echo """
  Commands for CentOS 7/8:

      sudo yum install nohang
      sudo cp ./examples/nohang.conf /etc/nohang/nohang.conf
      sudo systemctl enable nohang.service
      sudo systemctl start nohang.service

  Commands for Ubuntu 20:

      sudo add-apt-repository ppa:oibaf/test
      sudo apt install update
      sudo apt install nohang
      sudo cp ./examples/nohang.conf /etc/nohang/nohang.conf
      sudo systemctl enable nohang.service
      sudo systemctl start nohang.service

  Commands for Debian 11/Ubuntu 21+:

      sudo apt install nohang
      sudo cp ./examples/nohang.conf /etc/nohang/nohang.conf
      sudo systemctl enable nohang.service
      sudo systemctl start nohang.service
    """
    exit 1
  fi

  # check nohang config is good
  if ! (
       /usr/sbin/nohang --check --config /etc/nohang/nohang.conf | grep soft_threshold_min_mem | grep -q '35.0 %' \
    && /usr/sbin/nohang --check --config /etc/nohang/nohang.conf | grep soft_threshold_min_swap | grep -q '40 %' \
    && /usr/sbin/nohang --check --config /etc/nohang/nohang.conf | grep hard_threshold_min_mem | grep -q '30.0 %' \
    && /usr/sbin/nohang --check --config /etc/nohang/nohang.conf | grep hard_threshold_min_swap | grep -q '30 %'
  ) ; then
    echo
    echo "Cannot verify 'nohang' configuration at /etc/nohang/nohang.conf"
    echo "Please install examples/nohang.conf to /etc/nohang/nohang.conf and restart the service:"
    echo
    echo "      sudo cp '$PWD/examples/nohang.conf' /etc/nohang/nohang.conf"
    echo "      sudo systemctl restart nohang"
    echo
    exit 1
  fi

  # check nohang program is running
  if ! ( ps aux | grep -v grep | grep nohang | grep /usr/sbin/nohang -q || 
	  ps aux | grep -v grep | grep nohang | grep /usr/bin/nohang -q); then
    echo "'nohang' not running, but configuration is correct. Please restart the 'nohang' service!"
    echo
    echo "          sudo systemctl restart nohang"
    exit 1
  fi
fi

if [ ! -z $pulldocker ]; then
  docker pull $image
fi

if [ ! -z $rmdocker ]; then (
  container=$(docker ps -f name=$name -aq)
  if [ ! -z $container ]; then (
    set -x
    docker stop $container --time=300
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
  --ulimit core=0 \
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

if [ -z $nowait ]; then
  docker exec $name ./cluster.py wait
fi
