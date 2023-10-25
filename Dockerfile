FROM python:3.11-bullseye

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONUNBUFFERED true

RUN set -e \
 && apt-get update -qq \
 && apt-get install  -qq -y --no-install-recommends \
    iproute2 sudo curl unzip libcap2-bin qemu-kvm dnsutils iptables netcat socat \
    apt-transport-https ca-certificates gnupg2 software-properties-common \
 && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
 && add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable" \
 && add-apt-repository \
   "deb [arch=arm64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable" \
 && apt-get update -qq \
 && apt-get install -qq -y docker-ce-cli \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/var && mkdir -p /app/bin

RUN curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.0/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.0.tgz \
  &&  mkdir -p /opt/cni/bin \
  && tar -C /opt/cni/bin -xzf cni-plugins.tgz \
  && rm -f cni-plugins.tgz

WORKDIR /app

ADD Pipfile Pipfile.lock ./
RUN pip3 install pipenv \
 && pipenv install --system --deploy --ignore-pipfile

ADD cluster.py  ./
RUN ./cluster.py install \
&& setcap cap_ipc_lock=+ep bin/vault

ADD docker-entrypoint.sh  ./
ENV DOCKER_BIN=/app/bin
ENV PATH="/app/bin:${PATH}"
ENTRYPOINT ["/app/docker-entrypoint.sh"]

