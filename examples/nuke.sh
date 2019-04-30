#!/bin/bash -ex

sudo supervisorctl stop all
rm -rf var

sudo supervisorctl start cluster:consul cluster:vault
./cluster.py autovault

sudo supervisorctl start cluster:nomad
