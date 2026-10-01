#!/usr/bin/env bash
# =============================================================================
# Dijalankan SEKALI saat Codespace / dev container dibuat (postCreateCommand).
#   1. Memasang alat jaringan yang sama dengan toolbox, supaya perintah juga
#      bisa dijalankan langsung di terminal Codespace.
#   2. Menyiapkan image lab (pull + build) tanpa menyalakan stack.
# Kegagalan di langkah 2 tidak menggagalkan pembuatan Codespace: jalankan saja
# "docker compose up -d --build --wait" nanti, image akan diunduh saat itu.
# =============================================================================
set -uo pipefail

echo "== Memasang alat jaringan (dig, ping, traceroute, curl, wget, nmap, nc, openssl, jq)"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  bind9-dnsutils bind9-host iputils-ping iputils-tracepath traceroute mtr-tiny \
  curl wget nmap netcat-openbsd openssl ca-certificates jq iproute2 whois \
  || echo "Sebagian alat gagal dipasang; semua alat tetap tersedia di toolbox."
sudo rm -rf /var/lib/apt/lists/*

echo "== Menunggu Docker di dalam Codespace siap"
# post-start.sh memastikan Docker menyala dengan benar (penjelasan ada di file itu).
bash "$(dirname "$0")/post-start.sh"
for _ in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then break; fi
  sleep 2
done
if ! docker info >/dev/null 2>&1; then
  echo "Docker belum siap. Nanti jalankan sendiri: docker compose up -d --build --wait"
  exit 0
fi

echo "== Menyiapkan image lab (belum menyalakan stack)"
ready=no
for attempt in 1 2 3; do
  if docker compose pull --ignore-buildable && docker compose build; then
    ready=yes
    break
  fi
  echo "Percobaan $attempt gagal (jaringan/registry sibuk?), mencoba lagi dalam 10 detik"
  sleep 10
done

echo
if [ "$ready" = yes ]; then
  echo "Siap. Nyalakan lab dengan:  docker compose up -d --build --wait"
else
  echo "Image belum lengkap. Nanti jalankan sendiri: docker compose up -d --build --wait"
fi
