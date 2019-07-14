#!/bin/bash -ex

if [ -z "$IP" ]; then
  IP="10.66.60.1"
fi

head() {
  curl --fail --silent --show-error -I $1
}

get() {
  curl --fail --silent --show-error $1 > /dev/null
}

dns() {
  DNSIP=$(set -x; dig +short @$IP $1)
  if [ -z "$DNSIP" ]; then
    echo "DNS lookup for $1 failed"
    exit 1
  fi
}


echo 'Redirect me to /ui/!'

echo "Checking consul..."
head $IP:8500/
get $IP:8500/
get $IP:8500/v1/status/leader

echo "Checking vault..."
head $IP:8200/
get $IP:8200/
get $IP:8200/v1/sys/leader
get $IP:8200/v1/sys/seal-status

echo "Checking nomad..."
head $IP:4646/
get $IP:4646/
get $IP:4646/v1/status/leader

echo "Checking services..."
get $IP:9990/
get $IP:9990/health
get $IP:9990/prometheus/
get $IP:9990/prometheus/-/healthy/
get $IP:9990/alertmanager/
get $IP:9990/alertmanager/-/healthy/
head $IP:9990/grafana/
get $IP:9990/grafana/
get $IP:9990/grafana/api/health

echo "Checking DNS..."
dns consul.service.consul
dns nomad.service.consul
dns fabio.service.consul

dns github.com
dns liquiddemo.org

if [ -s "$SKIP_IPTABLES_CHECK" ]; then
  printf "${BASH_SOURCE[0]} DONE!\n\n"
  exit 0
fi

echo "Port forwarding should be up for 80 and 443..."
sudo iptables -t nat -S | grep -- "-A PREROUTING .* -p tcp -m tcp --dport 80 -j DNAT --to-destination $IP:80"
sudo iptables -t nat -S | grep -- "-A PREROUTING .* -p tcp -m tcp --dport 443 -j DNAT --to-destination $IP:443"
printf "${BASH_SOURCE[0]} DONE!\n\n\n"
