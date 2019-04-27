#!/bin/bash
set -ex

BRIDGE_NAME=liquid-bridge
BRIDGE_ADDRESS=10.66.60.1

ip link delete $BRIDGE_NAME type bridge || echo 'nothing to delete'
ip link add name $BRIDGE_NAME type bridge
ip link set dev liquid-bridge up
ip link set dev $EXTERNAL_INTERFACE up
ip address add dev $BRIDGE_NAME $BRIDGE_ADDRESS/24
