#!/bin/bash
set -ex
IPTABLES_COMMENT="liquid investigations"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# DEFAULT TABLE
echo "CLEANING DEFAULT TABLE..."
NOWRULES=$(iptables --line-number -nL | grep "$IPTABLES_COMMENT" | awk '{print $2} {print $1}' | tac)
for rul in $NOWRULES; do
  echo "clearning rule $rul"
  iptables -D $rul
  sleep 0.01
done

# NAT TABLE
echo "CLEANING NAT TABLE..."
NOWRULES=$(iptables -t nat --line-number -nL | grep "$IPTABLES_COMMENT" | awk '{print $2} {print $1}' | tac)
for rul in $NOWRULES; do
  echo "clearning rule $rul"
  iptables -t nat -D $rul
  sleep 0.01
done

