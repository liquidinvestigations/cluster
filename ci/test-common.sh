#!/bin/bash -ex

echo 'Redirect me to /ui/!'

head() {
  curl --fail --silent --show-error -I $1
}

get() {
  curl --fail --silent --show-error $1 > /dev/null
}

dns() {
  DNSIP=$(dig +short @10.66.60.1 $1)
  if [ -z $DNSIP ]; then
    echo "DNS lookup for $1 failed"
    exit 1
  fi
}


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

echo "Checking DNS..."
dns consul.service.consul
dns nomad.service.consul
dns fabio.service.consul

dns github.com
dns liquiddemo.org

# TODO: enable this check after we upgrade grafana to 6.3 (to have it pick up
# serve_from_sub_path) Alternatively, use the `master` branch.
#head 10.66.60.1:9990/grafana/
