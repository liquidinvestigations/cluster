#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"/..

read -p "$0: Are you sure? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then

  echo
  # Start RESET procedure...
  if ! docker exec cluster true; then
    echo "ERROR: Cluster container not found! Nothing to shut down & reset. Exiting..."
    exit 1
  fi

  if ! [ -f ../node/liquid ]; then
    echo "ERROR: '..node/liquid' excutable not found. Please run reset manually."
    echo "See https://github.com/liquidinvestigations/docs/wiki/Maintenance"
    exit 1
  fi

  echo "Running './node/liquid halt' ..."
  echo "------------------------------"

  (
  set -x
  ../node/liquid halt || true
  )
  sleep 10
  ../node/liquid halt || (
    echo "ERROR: '../liquid halt' failed, please run process manually."
    echo "See https://github.com/liquidinvestigations/docs/wiki/Maintenance"
    exit 1
  )

  echo "Running 'docker stop -t 300 cluster' ..."
  echo "------------------------------"

  (
  set -x
  docker stop -t 300 cluster
  )

  echo "Deleting all containers..."
  echo "------------------------------"
  (
  set -x
  docker stop -t 300 $(docker ps -q) || true
  docker rm -f $(docker ps -qa) || true
  )

  echo "Running 'sudo rm -rf ./var/nomad/*' ..."
  echo "------------------------------"
  (
  set -x
  sudo rm -rf ./var/nomad/*
  )

  echo ""
  echo "If other nodes exist in cluster, please delete their containers manually."
  echo "Reset: ALL DONE."
  # end RESET procedure
else
  echo "Confirmation denied, exiting."
  exit 1
fi
