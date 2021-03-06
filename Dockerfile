FROM python:3.7-stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    sudo curl unzip libcap2-bin qemu-kvm dnsutils iptables netcat socat \
    apt-transport-https ca-certificates gnupg2 software-properties-common \
 && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
 && add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable" \
 && apt-get update -qq \
 && apt-get install -qq -y docker-ce-cli \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/var && mkdir -p /app/bin

WORKDIR /app

ADD cluster.py docker-entrypoint.sh Pipfile Pipfile.lock ./
RUN pip3 install pipenv \
 && pipenv install --system --deploy --ignore-pipfile
RUN ./cluster.py install \
&& setcap cap_ipc_lock=+ep bin/vault

ENV DOCKER_BIN=/app/bin
ENTRYPOINT ["/app/docker-entrypoint.sh"]
