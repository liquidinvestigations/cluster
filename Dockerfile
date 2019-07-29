FROM python:3.7-stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    sudo curl unzip libcap2-bin qemu-kvm dnsutils iptables \
 && pip3 install pipenv \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/var /app/etc /app/bin

WORKDIR /app
ADD cluster.py docker-entrypoint.sh Pipfile Pipfile.lock ./

RUN pipenv install --system --deploy --ignore-pipfile \
 && ./cluster.py install \
 && setcap cap_ipc_lock=+ep bin/vault

ENV DOCKER_BIN=/app/bin
ENTRYPOINT ["/app/docker-entrypoint.sh"]
