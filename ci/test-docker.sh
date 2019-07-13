#!/bin/bash -ex

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

echo "waiting for docker"
until docker version; do sleep 1; done

echo "building docker image"
docker build . --tag liquidinvestigations/cluster

echo "running container"
cp examples/cluster.ini .
./examples/docker.sh

echo "spam the logs"
docker logs -f cluster &
docker exec cluster ./cluster.py supervisorctl -- tail -f start &

echo "waiting for service health checks"
docker exec cluster ./cluster.py wait

echo "running common tests"
./ci/test-common.sh

echo "stopping everything"
docker stop cluster
if [ -s "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    exit 1
fi

echo "restarting it"
docker start cluster
docker exec cluster ./cluster.py wait

echo "running common tests (again)"
./ci/test-common.sh

echo "done!"
