#!/bin/bash
set -ex

IPTABLES_COMMENT="liquid investigations firewall"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Set up iptables ALLOW & DENY rules
# provided in "$forward_ports".

# Have these variables:
# - address = the nomad bridge address where all services are hoisted
# - allowed_ips = a list of subnets to allow inbound & outbound for IP = address
# - allowed_ports = a list of ports to allow inbound & outbound for IP = address
# - docker_network_name
# - docker_network_subnet

echo "address: $address"
echo "allowed_ips: $allowed_ips"
echo "allowed_ports: $allowed_ports"
echo "docker_network_name: $docker_network_name"
echo "docker_network_subnet: $docker_network_subnet"

if [ -z "$address" ] \
    || [ -z "$allowed_ips" ] \
    || [ -z "$allowed_ports" ]; then
  echo "missing envs!" > /dev/stderr
  exit 1
fi

OLDIFS=$IFS
IFS=','
read -ra ports <<< "$allowed_ports"
IFS="$OLDIFS"

OLDIFS=$IFS
IFS=','
read -ra ips <<< "$allowed_ips"
IFS="$OLDIFS"

# create docker network
if ( docker network ls --no-trunc --format '{{.Name}}' | grep -q "$docker_network_name" ); then
  docker network create --subnet "$docker_network_subnet" "$docker_network_name"
fi

# iptables --insert DOCKER-USER -s "$docker_network_subnet" -j REJECT --reject-with icmp-port-unreachable -m comment --comment "$IPTABLES_COMMENT"
# iptables --insert DOCKER-USER -s "$docker_network_subnet" -m state --state RELATED,ESTABLISHED -j RETURN -m comment --comment "$IPTABLES_COMMENT"

for port in "${ports[@]}"; do
  for allowed_ip in "${ips[@]}"; do
    echo "ip: $allowed_ip, port: $port"
  done
done

echo "Firewall rules set up successfully."

