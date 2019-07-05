#!/bin/bash -ex

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

bridge_name=liquid-bridge
bridge_address=10.66.60.1
public_address=$(ip route get 8.8.8.8 | awk '{ print $7; exit }')

ip link add name $bridge_name type bridge
ip link set dev $bridge_name up
ip address add dev $bridge_name $bridge_address/24

dnat_to_bridge_http="-d $public_address -p tcp --dport 80 -j DNAT --to-destination $bridge_address"
dnat_to_bridge_https="-d $public_address -p tcp --dport 443 -j DNAT --to-destination $bridge_address"

iptables -t nat -D PREROUTING $dnat_to_bridge_http || /bin/true
iptables -t nat -A PREROUTING $dnat_to_bridge_http
iptables -t nat -D PREROUTING $dnat_to_bridge_https || /bin/true
iptables -t nat -A PREROUTING $dnat_to_bridge_https

echo iptables -t nat -A POSTROUTING -o $bridge_name -j MASQUERADE

echo 1 > /proc/sys/net/ipv4/ip_forward

echo "Network set up successfully." > /dev/null
