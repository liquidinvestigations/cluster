FROM python:3.7-stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    python3 curl unzip supervisor libcap2-bin \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/cluster \
 && ln -s /opt/cluster/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf

WORKDIR /opt/cluster
ADD cluster.py ./

RUN ./cluster.py install
RUN setcap cap_ipc_lock=+ep bin/vault

ADD runcluster ./

VOLUME /opt/cluster/var
EXPOSE 8500
EXPOSE 8200
EXPOSE 4646

CMD ./runcluster
