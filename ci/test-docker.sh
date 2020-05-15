#!/bin/bash -ex

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

echo "waiting for docker"
until docker version; do sleep 1; done

echo "building docker image"
docker build . --tag test-cluster

echo "running container"
cp examples/cluster.ini .
./bin/docker.sh --image test-cluster
export CLUSTER_COMMAND="docker exec cluster ./cluster.py"

echo "spam the logs"
docker logs -f cluster &
$CLUSTER_COMMAND supervisorctl -- tail -f start &

echo "waiting for service health checks"
$CLUSTER_COMMAND wait

echo "running common tests"
./ci/test-common.sh

echo "stopping everything"
docker stop cluster
sleep 3
if [ -n "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    docker ps
    exit 1
fi

echo "restarting it"
docker start cluster
$CLUSTER_COMMAND wait

echo "running common tests (again)"
./ci/test-common.sh

echo "done!"
