FROM python:3.7-stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    python3 curl unzip supervisor \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/cluster \
 && ln -s /opt/cluster/etc/supervisor-cluster.conf /etc/supervisor/conf.d/cluster.conf

WORKDIR /opt/cluster
ADD cluster.py ./
ADD examples/docker-cluster.ini ./cluster.ini
RUN ./cluster.py install

RUN set -e \
  && echo "[program:autovault]" >> /tmp/autovault.conf \
  && echo "command = bash -c 'cd /opt/cluster && ./cluster.py autovault && chmod 666 /opt/cluster/var/vault-secrets.ini && supervisorctl restart cluster:nomad'" >> /tmp/autovault.conf \
  && echo "autostart = true" >> /tmp/autovault.conf \
  && echo "autorestart = false" >> /tmp/autovault.conf \
  && mv /tmp/autovault.conf /etc/supervisor/conf.d/autovault.conf

VOLUME /opt/cluster/var

CMD ./cluster.py configure && supervisord -c /etc/supervisor/supervisord.conf -n
