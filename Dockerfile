FROM python:3.7-stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    sudo curl unzip libcap2-bin qemu-kvm dnsutils \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/cluster

WORKDIR /opt/cluster

ADD Pipfile Pipfile.lock ./
RUN pip3 install pipenv \
 && pipenv install --system --deploy --ignore-pipfile

ADD . .

RUN set -e \
 && ./cluster.py install \
 && setcap cap_ipc_lock=+ep bin/vault

VOLUME /opt/cluster/var

ENTRYPOINT ["/opt/cluster/docker-entrypoint.sh"]
