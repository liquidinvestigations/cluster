#!/bin/bash -ex

cd "$( dirname "${BASH_SOURCE[0]}" )"

echo "Starting Vagrant"
set -x
set +e

vagrant up --no-provision
echo 'sudo shutdown +15' | vagrant ssh
vagrant provision
ret=$?

set +x
echo
echo "Stats"
vagrant ssh <<EOF
set -x
uname -a
w
df -h
free -h
EOF

echo
echo "Destroying Vagrant"
vagrant destroy -f
exit $ret
