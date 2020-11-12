#!/bin/bash -ex

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -yqq git unzip supervisor docker.io python3-pip python3-venv
pip3 install --system pipenv
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/es.conf
sysctl --system
adduser vagrant docker

chown vagrant: /opt

mkdir /opt/cluster
cd /opt/cluster
tar xzf /opt/cluster.tar.gz
cp ci/vm-cluster.ini .

chown -R vagrant: .

docker pull liquidinvestigations/cluster
cat > /etc/supervisor/conf.d/boot-vm.conf <<EOF
[program:boot-vm]
user = vagrant
command = /opt/cluster/ci/boot-vm.sh
redirect_stderr = true
autostart = true
autorestart = false
EOF

echo "Provision done!"
