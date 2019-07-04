#!/bin/bash -ex

cd "$( dirname "${BASH_SOURCE[0]}" )"

export VAGRANT_DOTFILE_PATH=$(mktemp -d --tmpdir VAGRANT_DOTFILE_XXXXXXXX)
export VAGRANT_DEFAULT_PROVIDER=vmck
export VAGRANT_CHECKPOINT_DISABLE=true
export VAGRANT_BOX_UPDATE_CHECK_DISABLE=true

FILENAME=$(basename -- "$PROVISION")
STEM=${FILENAME%.*}
export VMNAME="$DRONE_REPO_NAME-$DRONE_BUILD_NUMBER-$STEM"
set +x

echo
echo '-----------------------------------------'
echo "Starting Vagrant"

vagrant up --no-provision || echo "vagrant up failed, VM might still work"
echo 'sudo shutdown +15' | vagrant ssh

set +e
vagrant provision
ret=$?
set -e

echo
echo '-----------------------------------------'
echo "Stats"

vagrant ssh <<'EOF'
for cmd in "uname -a" "w" "free -h" "df -h"; do
  echo
  echo "$cmd"
  $cmd 2>&1
done
EOF

echo
echo '-----------------------------------------'
echo "Destroying Vagrant"
vagrant destroy -f || echo "vagrant destroy failed, but we don't care"
exit $ret
