#!/bin/bash -ex

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get -yqq install sudo git unzip python3-pip python3-venv supervisor curl wget iptables

echo "installing"
cp examples/cluster.ini .

sudo ./install
sudo systemctl restart supervisor

echo "spam the logs"
sudo ./ctl tail -f start &

echo "waiting for service health checks"
sudo ./cluster wait

echo "running common tests"
./ci/test-common.sh

echo "stopping everything"
sudo ./stop
sleep 3
if [ -n "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    docker ps
    exit 1
fi

echo "restarting it"
sudo ./restart
sudo ./cluster wait

echo "running common tests (again)"
./ci/test-common.sh

echo "done!"
