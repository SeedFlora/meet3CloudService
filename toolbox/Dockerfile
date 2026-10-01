# Toolbox Net Web Lab: Ubuntu 24.04 + alat jaringan untuk praktikum.
# Masuk ke dalamnya dengan:  docker compose exec toolbox bash
# Image dasar dari Amazon ECR Public; compose.yaml bisa menggantinya lewat LAB_REGISTRY.
ARG LAB_REGISTRY=public.ecr.aws/docker/library
FROM ${LAB_REGISTRY}/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

#   DNS         : bind9-dnsutils (dig, nslookup), bind9-host (host)
#   Konektivitas: iputils-ping (ping), iputils-tracepath (tracepath), traceroute, mtr-tiny
#   HTTP        : curl, wget
#   Port        : nmap, netcat-openbsd (nc)
#   TLS         : openssl, ca-certificates
#   Lain-lain   : jq (JSON), iproute2 (ip, ss), tcpdump, whois, less, nano
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bind9-dnsutils bind9-host \
      iputils-ping iputils-tracepath traceroute mtr-tiny \
      curl wget \
      nmap netcat-openbsd \
      openssl ca-certificates \
      jq iproute2 tcpdump whois less nano bash-completion procps \
 && rm -rf /var/lib/apt/lists/*

COPY motd bashrc /etc/netlab/
# /etc/netlab-toolbox menandai "ini toolbox" (dipakai scripts/healthcheck.sh).
RUN echo '. /etc/netlab/bashrc' >> /root/.bashrc \
 && touch /etc/netlab-toolbox

WORKDIR /lab
CMD ["sleep", "infinity"]
