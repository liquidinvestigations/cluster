#!/bin/bash -ex

# Set up local bridge network
#
#       sudo ./network-mac.sh
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

bridge_name=bridge1
bridge_address=10.66.60.1

ifconfig $bridge_name create
ifconfig $bridge_name $bridge_address/24 up

echo "Network set up successfully." > /dev/null
