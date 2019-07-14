#!/bin/bash -ex

id $(whoami)
cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )"

echo "waiting for docker"
until docker version; do sleep 1; done

echo "building docker image"
docker build . --tag liquidinvestigations/cluster

echo "running three containers..."
sudo mkdir /test
sudo chown $(whoami): /test/
for id in 1 2 4; do
  cp -a . /test/$id
  cp /test/$id/ci/configs/triple-$id.ini /test/$id/cluster.ini
  /test/$id/examples/docker.sh --name test-$id
done

echo "wait until one of them wins"
function get_one_secret_file() {
  count=$(find /test -path '*/var/vault-secrets.ini' | wc -l)
  onefile=$(find /test -path '*/var/vault-secrets.ini' | head -n1)
  case "$count" in
    "0") echo "no secret files" >&2; return 1 ;;
    "1") echo "$onefile"; return 0 ;;
    *) echo "too many vault-secrets.ini files!" >&2; exit 1
  esac
}
until get_one_secret_file; do sleep 5; done
winner=$(get_one_secret_file)

echo "copy config over to the losers"
docker stop test-1 test-2 test-4
for id in 1 2 4; do
  dest="/test/$id/var/vault-secrets.ini"
  if [ "$winner" != "$dest" ]; then
    cp "$winner" "$dest"
  fi
done

echo "restart these to pick up the changes"
docker start test-1 test-2 test-4

function wait_and_test() {
  for id in 1 2 4; do
    docker exec test-$id ./cluster.py wait
  done

  export SKIP_IPTABLES_CHECK=yes
  for id in 1 2 4; do
    export IP="10.66.60.$id"
    ./ci/test-common.sh
  done
}

echo "running tests"
wait_and_test

echo "kill and restart"
docker kill test-1 test-2 test-4
docker start test-1 test-2 test-4
wait_and_test

echo "done!"
