#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Set up iptables DNAT rules for a comma-separated list of PUBLIC:PRIVATE ports
# provided in "$forward_ports".

# Set these variables:
# - $bridge_address
# - $bridge_name
# - $forward_ports

if [ -z "$forward_ports" ]; then
  echo "No ports to forward."
  exit 0
fi

if [ -z "$forward_address" ]; then
# The public address used in the DNAT rule is guessed by:
  forward_address=$(ip route get 8.8.8.8 | awk '{ print $7; exit }')
fi

echo "Forwarding ports: $forward_ports..."

if [ -z "$forward_address" ] \
    || [ -z "$bridge_address" ] \
    || [ -z "$bridge_name" ] \
    || [ -z "$forward_ports" ]; then
  echo "missing envs!" > /dev/stderr
  exit 1
fi

OLDIFS=$IFS
IFS=','
read -ra ports <<< "$forward_ports"
IFS="$OLDIFS"

for pair in "${ports[@]}"; do
  public_port="$(cut -d: -f1 <<< "$pair")"
  private_port="$(cut -d: -f2 <<< "$pair")"
  if [ -z "$public_port" ] || [ -z "$private_port" ]; then
    echo "bad port pair: '$pair'" > /dev/stderr
    exit 1
  fi

  echo "DNAT $forward_address:$public_port --> $bridge_address:$private_port"
  rule="-d $forward_address -p tcp --dport $public_port -j DNAT --to-destination $bridge_address:$private_port"
  (
    set -x
    # TODO delete all rules matching source to this
    iptables -t nat -D PREROUTING $rule || /bin/true
    iptables -t nat -A PREROUTING $rule
  )
done

(
  set -x
  # delete duplicates of this rule that may have appeared
  rule="-o $bridge_name -j MASQUERADE"
  while iptables -t nat -D POSTROUTING $rule; do
    echo removed duplicate rule "POSTROUTING $rule"
  done
  iptables -t nat -A POSTROUTING $rule
)

echo "Firewall rules set up successfully."
