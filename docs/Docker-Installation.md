# Docker Installation

The simplest way to obtain a running system is to use the `bin/docker.sh` script.

This is only supported on Linux.


## Options for [bin/docker.sh](bin/docker.sh)

The script runs the Docker image with these parameters:

* `--name` container name (default: cluster)
* `--image` image (default: liquidinvestigations/cluster)
* `--pull` pull image

If a container with the same `name` already exists, it will be gracefully shut
down and removed.

---
To use a specific image version, run:

```bash
git fetch
git checkout vX.Y.Z

# edit cluster.ini

./bin/docker.sh --pull --image liquidinvestigations/cluster:X.Y.Z
```

Make sure the git repository has checked out the same version tag as the docker image.

See https://github.com/liquidinvestigations/docs/wiki/Maintenance for more details about upgrading the system.


## Running the container manually

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
for the user that's running the container. Of course, the user needs to be in
the `docker` group, and the GID of that group should be set as the env `DOCKERGROUPID`.

The volume path `./var` has to be the same both inside and outside the Docker
container. This is because both Nomad running inside the container and the
host dockerd access the data directory using the path inside the container.

Example usage: [ci/test-docker.sh](ci/test-docker.sh)

