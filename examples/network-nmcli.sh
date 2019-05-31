#!/bin/bash -ex

bridge_name=liquid-bridge
bridge_address=10.66.60.1

nmcli con add type bridge ifname $bridge_name ip4 $bridge_address/24

echo "Network set up successfully." > /dev/null
