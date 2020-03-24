#!/bin/bash -ex

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

pipenv --version
pipenv install 2>&1
export CLUSTER_COMMAND="pipenv run ./cluster.py"

echo "installing services"
$CLUSTER_COMMAND install
sudo setcap cap_ipc_lock=+ep bin/vault

echo "configuring"
cp examples/cluster.ini .
$CLUSTER_COMMAND configure

echo "setting up network"
sudo $CLUSTER_COMMAND configure-network

echo "running supervisord"
$CLUSTER_COMMAND supervisord -d

echo "spam the logs"
$CLUSTER_COMMAND supervisorctl -- tail -f start &

echo "waiting for service health checks"
$CLUSTER_COMMAND wait

echo "running common tests"
./ci/test-common.sh

echo "stopping everything"
$CLUSTER_COMMAND stop
if [ -n "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    exit 1
fi

echo "restarting it"
$CLUSTER_COMMAND supervisord -d
$CLUSTER_COMMAND wait

echo "running common tests (again)"
./ci/test-common.sh

echo "done!"
