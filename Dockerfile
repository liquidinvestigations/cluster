FROM python:3.7-stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    curl unzip supervisor libcap2-bin qemu-kvm \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/cluster \
 && ln -s /opt/cluster/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf

WORKDIR /opt/cluster
ADD cluster.py ./
ADD kubectl ./
ADD charts ./

RUN set -e \
 && ./cluster.py install \
 && setcap cap_ipc_lock=+ep bin/vault

ADD runcluster ./

VOLUME /opt/cluster/var
# consul
EXPOSE 8500
# vault
EXPOSE 8200
# nomad
EXPOSE 4646
# k3s
EXPOSE 6443
# sentry
EXPOSE 9000

CMD ./runcluster
