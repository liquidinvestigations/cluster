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

RUN set -e \
  && echo "[supervisor]" > cluster.ini \
  && echo "autostart = on" >> cluster.ini \
  && echo "[nomad]" >> cluster.ini

RUN ./cluster.py install
RUN setcap cap_ipc_lock=+ep bin/vault

RUN set -e \
  && echo "[program:autovault]" >> /tmp/autovault.conf \
  && echo "command = bash -c 'cd /opt/cluster && ./cluster.py autovault && chmod 666 /opt/cluster/var/vault-secrets.ini && supervisorctl restart cluster:nomad'" >> /tmp/autovault.conf \
  && echo "autostart = true" >> /tmp/autovault.conf \
  && echo "autorestart = false" >> /tmp/autovault.conf \
  && mv /tmp/autovault.conf /etc/supervisor/conf.d/autovault.conf

VOLUME /opt/cluster/var
EXPOSE 8500
EXPOSE 8200
EXPOSE 4646

ENV NOMAD_CLIENT_INTERFACE eth0
CMD echo "interface = $NOMAD_CLIENT_INTERFACE" >> cluster.ini && ./cluster.py configure && exec supervisord -c /etc/supervisor/supervisord.conf -n
