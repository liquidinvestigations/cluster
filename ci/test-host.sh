#!/bin/bash -ex

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

echo "setting up network"
sudo ./examples/network.sh

echo "installing dependencies"
sudo apt-get update -yqq > /dev/null
sudo apt-get install -yqq python3-pip python3-venv git curl unzip dnsutils > /dev/null
pip3 install --user --upgrade pipenv > /dev/null
export PATH="~/.local/bin:$PATH"
pipenv --version
pipenv install > /dev/null

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
if [ -s "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    exit 1
fi

echo "restarting it"
pipenv run ./cluster.py supervisord -d
pipenv run ./cluster.py wait

echo "running common tests (again)"
./ci/test-common.sh

echo "done!"
