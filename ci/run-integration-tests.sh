#!/bin/bash -ex

cd "$( dirname "${BASH_SOURCE[0]}" )"/..

cd "$(dirname ${BASH_SOURCE[0]})/.."
CLUSTER1=/opt/cluster1
CLUSTER1=/opt/cluster2
CLUSTER1=/opt/cluster4

function docker_killall {
  docker kill $(docker ps -q) >/dev/null 2>/dev/null || true
}


function wipe {
  ( pipenv --rm || true ) &
  docker kill cluster test-cluster cluster-test test-1 test-2 test-4 || true
  docker_killall
  docker rm -f cluster test-cluster cluster-test test-1 test-2 test-4 || true
  sudo rm -rf ~/triple-test || true
  sudo rm -rf /tmp/volumes || true
  sudo killall nomad || true
  sudo killall consul || true
  sudo killall vault || true

  wait
}


function install {
  sudo mkdir -p $CLUSTER1/var/
  sudo mkdir -p $CLUSTER2/var/
  sudo mkdir -p $CLUSTER4/var/

  pipenv install  &

  git fetch --tags  &

  wait
}


# don't leave cadavers on testing server for this repository
trap wipe EXIT

wipe
install


echo '-------------------------------'
./ci/test-docker.sh
./ci/test-host.sh
./ci/test-triple.sh
