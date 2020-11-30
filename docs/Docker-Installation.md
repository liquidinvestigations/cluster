# Docker Installation

Consul, Vault and Nomad can run in one Docker container with host networking
mode with these settings:

```bash
docker run --detach \
  --name cluster \
  --restart always \
  --privileged \
  --net host \
  --env USERID=123 \
  --env GROUPID=456 \
  --env DOCKERGROUPID=789 \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume "$PWD:$PWD" \
  --workdir "$PWD" \
  liquidinvestigations/cluster
```

You need to provide `cluster.ini` (there is one in `examples/`) and UID/GIDs
for the user that's running the container. Of course, the user (which should 
be different from root) needs to be in the `docker` group, and the GID of that 
group should be set as the env `DOCKERGROUPID`.

The volume path `./var` has to be the same both inside and outside the Docker
container. This is because both Nomad running inside the container and the
host dockerd access the data directory using the path inside the container.

Example usage: [ci/test-docker.sh](ci/test-docker.sh)

## Options using [bin/docker.sh](bin/docker.sh)

You can use these additional options to modify the docker based startup procedure as used in the Quick Start section above:

* `--name` container name (default: cluster)
* `--image` image (default: liquidinvestigations/cluster)
* `--rm` remove docker container first (default: don't remove container)
* `--pull` pull image

To perform an update, run:

```bash
./bin/docker.sh --rm --pull
```
