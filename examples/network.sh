#!/bin/bash
set -ex

# Set up local bridge network
#
#       sudo ./network.sh
#
# Then edit `cluster.ini` and edit:
#
#       [nomad]
#       interface = liquid-bridge
#       address = 10.66.60.01
#       advertise = 10.66.60.01
#
#       [vault]
#       address = 10.66.60.01
#
#       [consul]
#       address = 10.66.60.01

BRIDGE_NAME=liquid-bridge
BRIDGE_ADDRESS=10.66.60.1

ip link delete $BRIDGE_NAME type bridge || echo 'nothing to delete'
ip link add name $BRIDGE_NAME type bridge
ip link set dev $BRIDGE_NAME up
ip address add dev $BRIDGE_NAME $BRIDGE_ADDRESS/24

# TODO: add bridge to external interface
# TODO: firewall
