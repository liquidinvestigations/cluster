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

bridge_name=liquid-bridge
bridge_address=10.66.60.1
public_interface=$(route get 8.8.8.8 | awk '/interface:/ {print $2}')

ifconfig $public_interface alias $bridge_address/24 up

echo "Network set up successfully." > /dev/null
