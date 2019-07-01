#!/bin/bash -ex

echo 'Redirect me to /ui/!'

curl --silent 10.66.60.1:8500/
curl --silent 10.66.60.1:4646/
curl --silent 10.66.60.1:8200/
