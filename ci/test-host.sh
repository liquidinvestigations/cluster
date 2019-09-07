#!/bin/bash -ex

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

sudo apt-get install -qq python3-pip
sudo pip3 install pipenv
pipenv --version
pipenv install 2>&1

echo "installing services"
pipenv run ./cluster.py install
sudo setcap cap_ipc_lock=+ep bin/vault

echo "configuring"
cp examples/cluster.ini .
pipenv run ./cluster.py configure

echo "setting up network"
sudo pipenv run ./cluster.py configure-network

echo "running supervisord"
pipenv run ./cluster.py supervisord -d

echo "spam the logs"
pipenv run ./cluster.py supervisorctl -- tail -f start &

echo "waiting for service health checks"
pipenv run ./cluster.py wait

echo "running common tests"
./ci/test-common.sh

echo "stopping everything"
pipenv run ./cluster.py stop
if [ -n "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    exit 1
fi

echo "restarting it"
pipenv run ./cluster.py supervisord -d
pipenv run ./cluster.py wait

echo "running common tests (again)"
./ci/test-common.sh

echo "done!"
