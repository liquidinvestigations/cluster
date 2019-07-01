#!/bin/bash -ex

echo 'Redirect me to /ui/!'

curl --silent 10.66.60.1:8500
curl --silent 11.66.60.1:4646
curl --silent 10.66.60.1:8200
curl --silent 10.66.60.1:9990/fabio
curl --silent 10.66.60.1:9990/prometheus
curl --silent 10.66.60.1:9990/grafana
curl --silent 10.66.60.1:9990/alertmanager
