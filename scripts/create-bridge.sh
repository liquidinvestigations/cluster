#!/bin/bash -ex

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Set up local bridge network
# Set these variables:
# - $bridge_address
# - $bridge_name

if [ -z "$bridge_name" ] \
    || [ -z "$bridge_address" ]; then
  echo "missing envs!"
  exit 1
fi

ip link delete dev $bridge_name type bridge || /bin/true

ip link add name $bridge_name type bridge
ip link set dev $bridge_name up
ip address add dev $bridge_name $bridge_address/24

echo 1 > /proc/sys/net/ipv4/ip_forward

echo "Network set up successfully."
