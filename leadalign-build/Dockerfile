FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update --allow-unauthenticated --allow-insecure-repositories -y && \
    mkdir -p /bin && apt -y upgrade && apt -y install wget git && \
    apt -y update && apt -y upgrade && \
    apt install software-properties-common -y && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt -y update && \
    apt -y upgrade && \
    apt install -qq -y build-essential mariadb-client python3.12 python3.12-dev && \
    apt autoclean -y && apt autoremove -y --purge && apt clean 

ENV GO_VERSION=1.23.2
RUN wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz > /dev/null && tar -C /usr/local -xzvf go${GO_VERSION}.linux-amd64.tar.gz > /dev/null 2>&1 && rm -f go${GO_VERSION}.linux-amd64.tar.gz

ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin:/go/bin"

WORKDIR /go/src/github.com/cogo-datalign/leadalign

RUN mkdir -p /home/docker && chmod 777 /home/docker
ENV HOME=/home/docker
