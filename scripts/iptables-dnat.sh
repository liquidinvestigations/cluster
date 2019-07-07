#!/bin/bash -ex

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Set up iptables dnat for two ports (http and https)
# Set these variables:
# - $bridge_address
# - $bridge_name
# - $forward_ports

# The public address that is set the DNAT destination is
# guessed by:
public_address=$(ip route get 8.8.8.8 | awk '{ print $7; exit }')

if [ -z "$public_address" ] \
    || [ -z "$bridge_address" ] \
    || [ -z "$bridge_name" ] \
    || [ -z "$forward_ports" ]; then
  echo "missing envs!"
  exit 1
fi

echo TODO
exit 0

dnat_to_bridge_http="-d $public_address -p tcp --dport $http_port -j DNAT --to-destination $bridge_address"
dnat_to_bridge_https="-d $public_address -p tcp --dport $https_port -j DNAT --to-destination $bridge_address"

iptables -t nat -D PREROUTING $dnat_to_bridge_http || /bin/true
iptables -t nat -A PREROUTING $dnat_to_bridge_http
iptables -t nat -D PREROUTING $dnat_to_bridge_https || /bin/true
iptables -t nat -A PREROUTING $dnat_to_bridge_https
iptables -t nat -A POSTROUTING -o $bridge_name -j MASQUERADE

echo "Firewall rules set up successfully."
