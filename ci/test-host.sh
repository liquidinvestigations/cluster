#!/bin/bash -ex

cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

echo "setting up network"
sudo ./examples/network.sh

echo "installing dependencies"
apt-get update -yqq && apt-get install -yqq python3-pip git curl unzip
pip3 install pipenv
pipenv install

exec pipenv shell <<'EOF'

echo "installing services"
./cluster.py install
sudo setcap cap_ipc_lock=+ep bin/vault

echo "configuring"
cp examples/cluster.ini .
./cluster.py configure

echo "running supervisord"
./cluster.py supervisord -d

echo "spam the logs"
./cluster.py supervisorctl -- tail -f start &

echo "waiting for service health checks"
./cluster.py wait

echo "running common tests"
./ci/test-common.sh

echo "stopping everything"
./cluster.py stop
docker ps
if [ -s "$(docker ps -q)" ]; then
    echo "some docker containers still up!"
    exit 1
fi

echo "done!"
EOF
