#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"

export VAGRANT_DOTFILE_PATH=$(mktemp -d --tmpdir VAGRANT_DOTFILE_XXXXXXXX)
export VAGRANT_DEFAULT_PROVIDER=vmck
export VAGRANT_CHECKPOINT_DISABLE=true
export VAGRANT_BOX_UPDATE_CHECK_DISABLE=true

FILENAME=$(basename -- "$PROVISION")
STEM=${FILENAME%.*}
export VMNAME="$DRONE_REPO_NAME-$DRONE_BUILD_NUMBER-$STEM"
set +e

set +x
echo
echo '-----------------------------------------'
echo "Starting Vagrant"
set -x

vagrant up --no-provision
echo 'sudo shutdown +15' | vagrant ssh
vagrant provision
ret=$?

set +x
echo
echo '-----------------------------------------'
echo "Stats"

vagrant ssh <<'EOF'
for cmd in "uname -a" "w" "free -h" "df -h"; do
  echo "$cmd"
  $cmd 2>&1
  echo
done
EOF

echo
echo '-----------------------------------------'
echo "Destroying Vagrant"
vagrant destroy -f
exit $ret
