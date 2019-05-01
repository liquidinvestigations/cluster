#!/bin/bash -ex

sudo supervisorctl stop all
rm -rf var

./cluster.py configure
sudo supervisorctl start cluster:consul cluster:vault
./cluster.py autovault

sudo supervisorctl start cluster:nomad
