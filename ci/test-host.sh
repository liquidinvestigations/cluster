#!/bin/bash -ex

cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

echo "setting up network"
sudo ./examples/network.sh

echo "installing dependencies"
apt-get update -yqq && apt-get install -yqq python3-pip python3-venv git curl unzip
pip3 install pipenv
pipenv install

echo "installing services"
pipenv run ./cluster.py install
sudo setcap cap_ipc_lock=+ep bin/vault

echo "configuring"
cp examples/cluster.ini .
pipenv run ./cluster.py configure

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
docker ps
if [ -s "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    exit 1
fi

echo "done!"
