#!/bin/bash -ex

# Set up a pair of local bridge networks
#
#       sudo ./network-mac.sh

# Then edit `cluster.ini` and edit:
#       [network]
#       address = 10.66.60.1
#       interface = services-bridge

cluster_bridge_name=bridge1
cluster_bridge_address=10.66.60.1

services_bridge_name=bridge2
services_bridge_address=10.66.60.2

ifconfig $cluster_bridge_name destroy || true
ifconfig $cluster_bridge_name create
ifconfig $cluster_bridge_name $cluster_bridge_address/32 up

ifconfig $services_bridge_name destroy || true
ifconfig $services_bridge_name create
ifconfig $services_bridge_name $services_bridge_address/32 up

echo "Network set up successfully." > /dev/null
