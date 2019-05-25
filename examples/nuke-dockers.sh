#!/bin/bash
set -e

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 host1 host2 host3"
  exit 1
fi

for host in "$@"; do
  echo "Nuking $host"
  ssh -T $host <<-'EOF'
    set -ex
    cd /opt/cluster
    docker stop $(docker ps -q) || true
    docker kill $(docker ps -q) || true
    docker rm $(docker ps -qa) || true
    sudo rm -rf var/nomad
EOF
done

for host in "$@"; do
  echo "Starting $host"
  ssh -T $host <<-'EOF'
    set -ex
    cd /opt/cluster
    ./examples/docker.sh
EOF
done
