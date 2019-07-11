#!/bin/bash -ex

head() {
  curl --fail --silent --show-error -I $1
}

get() {
  curl --fail --silent --show-error $1 > /dev/null
}

dns() {
  DNSIP=$(set -x; dig +short @10.66.60.1 $1)
  if [ -z "$DNSIP" ]; then
    echo "DNS lookup for $1 failed"
    exit 1
  fi
}


echo 'Redirect me to /ui/!'

echo "Checking consul..."
head 10.66.60.1:8500/
get 10.66.60.1:8500/
get 10.66.60.1:8500/v1/status/leader

echo "Checking vault..."
head 10.66.60.1:8200/
get 10.66.60.1:8200/
get 10.66.60.1:8200/v1/sys/leader
get 10.66.60.1:8200/v1/sys/seal-status

echo "Checking nomad..."
head 10.66.60.1:4646/
get 10.66.60.1:4646/
get 10.66.60.1:4646/v1/status/leader

echo "Checking services..."
get 10.66.60.1:9990/
get 10.66.60.1:9990/health
get 10.66.60.1:9990/prometheus/
get 10.66.60.1:9990/prometheus/-/healthy/
get 10.66.60.1:9990/alertmanager/
get 10.66.60.1:9990/alertmanager/-/healthy/
head 10.66.60.1:9990/grafana/
get 10.66.60.1:9990/grafana/
get 10.66.60.1:9990/grafana/api/health/

echo "Checking DNS..."
dns consul.service.consul
dns nomad.service.consul
dns fabio.service.consul

dns github.com
dns liquiddemo.org

echo "Port forwarding should be up for 80 and 443..."
sudo iptables -t nat -S | grep 80
sudo iptables -t nat -S | grep 443
printf "${BASH_SOURCE[0]} DONE!\n\n\n"
