#!/bin/bash -ex

echo "installing consul connect requirements"
if ! [ -d /opt/cni/bin ]; then
    curl -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.1/cni-plugins-linux-amd64-v0.8.1.tgz
    sudo mkdir -p /opt/cni/bin
    sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz
    rm -f cni-plugins.tgz
fi
cd /tmp
sudo modprobe br-netfilter

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

pipenv --version
pipenv install 2>&1

echo "installing services"
pipenv run ./cluster.py install
sudo -n setcap cap_ipc_lock=+ep bin/vault

echo "configuring"
cp examples/cluster.ini .
pipenv run ./cluster.py configure

echo "setting up network"
sudo -E pipenv run ./cluster.py configure-network

echo "running supervisord"
sudo -E pipenv run ./cluster.py supervisord -d

echo "spam the logs"
sudo -E pipenv run ./cluster.py supervisorctl -- tail -f start &

echo "waiting for service health checks"
sudo -E pipenv run ./cluster.py wait

echo "running common tests"
./ci/test-common.sh

echo "stopping everything"
sudo -E pipenv run ./cluster.py stop
if [ -n "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    exit 1
fi

echo "restarting it"
sudo -E pipenv run ./cluster.py supervisord -d
sudo -E pipenv run ./cluster.py wait

echo "running common tests (again)"
./ci/test-common.sh

echo "done!"
