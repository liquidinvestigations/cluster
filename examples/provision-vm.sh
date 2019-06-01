#!/bin/bash -ex

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -yqq git python3 unzip docker.io supervisor python3-venv
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/es.conf
sysctl --system
adduser vagrant docker

mkdir /opt/cluster
cd /opt/cluster
tar xzvf /opt/cluster.tar.gz
chown vagrant: .

cp examples/cluster.ini .

cat > /etc/supervisor/conf.d/boot-vm.conf <<EOF
[program:boot-vm]
command = /opt/cluster/examples/boot-vm.sh
redirect_stderr = true
autostart = true
autorestart = false
EOF

echo "Provision done!"
