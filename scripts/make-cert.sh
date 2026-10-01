#!/usr/bin/env bash
# =============================================================================
# make-cert.sh: membuat sertifikat self-signed untuk HTTPS di Net Web Lab.
#
# Jalankan dari folder repo, di terminal Codespaces/laptop atau di toolbox:
#   bash scripts/make-cert.sh
#   docker compose exec toolbox bash scripts/make-cert.sh
#
# Hasil (berlaku 30 hari):
#   web/certs/lab.crt  sertifikat (berisi public key, boleh dibagikan)
#   web/certs/lab.key  private key (RAHASIA, sudah masuk .gitignore)
#
# Isi skrip ini hanya satu perintah openssl, sama dengan yang Anda ketik manual
# di praktikum. Nama di subjectAltName (SAN) adalah nama yang boleh dipakai klien:
# localhost (dari host), web (dari dalam jaringan Docker), dan IP 127.0.0.1.
# =============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash (Windows): jangan ubah "/CN=..." menjadi path Windows

cd "$(dirname "$0")/.."
DAYS="${DAYS:-30}"
mkdir -p web/certs

if ! openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
      -keyout web/certs/lab.key -out web/certs/lab.crt -days "$DAYS" \
      -subj "/CN=localhost" \
      -addext "subjectAltName=DNS:localhost,DNS:web,IP:127.0.0.1"; then
  echo "Gagal membuat sertifikat. Coba jalankan di toolbox:" >&2
  echo "  docker compose exec toolbox bash scripts/make-cert.sh" >&2
  exit 1
fi

# Dijalankan sebagai root (misalnya di toolbox)? Kembalikan pemilik file ke pemilik
# folder repo, supaya file tetap bisa diedit/dihapus dari editor di host.
if [ "$(id -u)" = "0" ]; then
  owner="$(stat -c '%u:%g' . 2>/dev/null || true)"
  if [ -n "$owner" ]; then chown "$owner" web/certs/lab.crt web/certs/lab.key 2>/dev/null || true; fi
fi
chmod 644 web/certs/lab.crt
chmod 600 web/certs/lab.key

echo
echo "Sertifikat dibuat: web/certs/lab.crt (private key: web/certs/lab.key)"
openssl x509 -in web/certs/lab.crt -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null \
  || openssl x509 -in web/certs/lab.crt -noout -subject -issuer -dates
echo
echo "Bila nginx sudah memakai HTTPS, muat ulang agar sertifikat baru terpakai:"
echo "  docker compose exec web nginx -s reload"
