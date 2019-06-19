FROM python:3.7-stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    curl unzip supervisor libcap2-bin qemu-kvm \
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
EXPOSE 8500
EXPOSE 8600
EXPOSE 8200
EXPOSE 4646

CMD ./cluster.py supervisord
