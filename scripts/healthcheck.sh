#!/usr/bin/env bash
# =============================================================================
# healthcheck.sh: membuktikan desain Net Web Lab dengan alat jaringan.
# Bagian dari TANTANGAN DESAIN. Jalankan DI DALAM toolbox, dari folder repo:
#
#   docker compose exec toolbox bash scripts/healthcheck.sh
#
# Tugas Anda: lengkapi lima fungsi check_* di bawah (cari tulisan "TODO").
#   - Panggil  ok  "pesan"   bila pemeriksaan lolos.
#   - Panggil  bad "pesan"   bila pemeriksaan gagal.
#   - Hapus baris  todo "..."  setelah fungsinya Anda isi.
# Skrip keluar dengan kode 0 hanya bila tidak ada yang gagal dan tidak ada TODO.
# tests/challenge.sh (dan GitHub Actions) menjalankan skrip ini dan mengharapkan
# kode 0 dengan minimal 10 pemeriksaan lolos.
# =============================================================================
set -u

# --- Konfigurasi (boleh diubah lewat environment variable) --------------------
WEB="${WEB:-web}"                          # nama service di jaringan Docker
API="${API:-api}"
DB="${DB:-db}"
OUTSIDE="${OUTSIDE:-host.docker.internal}" # host Docker = "pandangan dari luar"
HTTPS_PORT="${HTTPS_PORT:-8443}"           # port HTTPS yang dipublish ke host
CA="${CA:-/lab/web/certs/lab.crt}"         # sertifikat dari scripts/make-cert.sh
TIMEOUT="${TIMEOUT:-3}"                    # batas waktu koneksi (detik)

# --- Helper (tidak perlu diubah) ----------------------------------------------
PASSED=0; FAILED=0; TODOS=0
ok()      { PASSED=$((PASSED + 1)); printf '  [ OK ]  %s\n' "$*"; }
bad()     { FAILED=$((FAILED + 1)); printf '  [GAGAL] %s\n' "$*"; }
todo()    { TODOS=$((TODOS + 1));   printf '  [TODO]  %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }
# port_open HOST PORT: sukses (kode 0) bila koneksi TCP berhasil dalam $TIMEOUT detik
port_open() { nc -z -w "$TIMEOUT" "$1" "$2" >/dev/null 2>&1; }

# --- 1. DNS -------------------------------------------------------------------
check_dns() {
  section "1. DNS: nama service ter-resolve oleh DNS internal Docker"
  # TODO: untuk setiap nama "$WEB" "$API" "$DB":
  #   ip=$(dig +short "$name" | head -n 1)
  #   bila $ip tidak kosong -> ok "$name -> $ip", bila kosong -> bad "$name tidak ter-resolve"
  # Petunjuk:  for name in "$WEB" "$API" "$DB"; do ... done
  todo "check_dns belum diisi (coba dulu: dig +short web)"
}

# --- 2. TCP -------------------------------------------------------------------
check_tcp() {
  section "2. TCP: port layanan terbuka di jaringan internal"
  # TODO: pastikan port berikut menerima koneksi, pakai fungsi port_open:
  #   web:80   web:443   api:3000   db:5432
  # Contoh satu port:
  #   if port_open "$WEB" 80; then ok "$WEB:80 terbuka"; else bad "$WEB:80 tertutup"; fi
  todo "check_tcp belum diisi (coba dulu: nc -zv web 80)"
}

# --- 3. HTTP ------------------------------------------------------------------
check_http() {
  section "3. HTTP: API sehat bila diakses lewat reverse proxy"
  # TODO: panggil http://$WEB/api/health dengan curl, lalu periksa:
  #   a) status code 200:
  #        code=$(curl -s -o /tmp/health.json -w '%{http_code}' --max-time "$TIMEOUT" "http://$WEB/api/health")
  #   b) isi JSON: status "ok" dan db "up":
  #        jq -e '.status == "ok" and .db == "up"' /tmp/health.json >/dev/null
  todo "check_http belum diisi (coba dulu: curl -i http://web/api/health)"
}

# --- 4. TLS -------------------------------------------------------------------
check_tls() {
  section "4. TLS: HTTPS aktif dan sertifikatnya valid untuk nama $WEB"
  # TODO:
  #   a) file "$CA" ada  ([ -s "$CA" ]); bila belum: bash scripts/make-cert.sh
  #   b) verifikasi sertifikat dengan CA file kita (hasil yang benar: 0 (ok)):
  #        openssl s_client -connect "$WEB:443" -servername "$WEB" -CAfile "$CA" \
  #          -verify_hostname "$WEB" </dev/null 2>/dev/null | grep -q 'Verify return code: 0 (ok)'
  #   c) sertifikat masih berlaku minimal 7 hari lagi:
  #        openssl x509 -in "$CA" -noout -checkend 604800
  #   d) curl lewat HTTPS berhasil (status 200):
  #        curl -s -o /dev/null -w '%{http_code}' --cacert "$CA" "https://$WEB/api/health"
  todo "check_tls belum diisi (coba dulu: openssl s_client -connect web:443 -servername web -brief </dev/null)"
}

# --- 5. Exposure (pandangan dari luar) ----------------------------------------
check_exposure() {
  section "5. Exposure: dari host Docker hanya port web yang terbuka"
  # "$OUTSIDE" adalah mesin host Docker. Port yang terbuka di sana adalah port
  # yang dipublish (bagian ports: di compose.yaml), jadi bisa dijangkau dari luar.
  # TODO:
  #   - port $HTTPS_PORT (HTTPS web) harus TERBUKA   -> ok / bad
  #   - port 3000 (api) dan 5432 (db) harus TERTUTUP -> ok bila port_open GAGAL
  #   Contoh:  if port_open "$OUTSIDE" 5432; then bad "5432 terbuka di host"; else ok "5432 tertutup"; fi
  todo "check_exposure belum diisi (coba dulu: nmap -p 3000,5432,8080,8443 host.docker.internal)"
}

# --- Main (tidak perlu diubah) -------------------------------------------------
main() {
  if [ ! -f /etc/netlab-toolbox ]; then
    echo "Skrip ini harus dijalankan di dalam toolbox:" >&2
    echo "  docker compose exec toolbox bash scripts/healthcheck.sh" >&2
    exit 2
  fi
  echo "Net Web Lab healthcheck ($(date '+%Y-%m-%d %H:%M:%S %Z'))"
  check_dns
  check_tcp
  check_http
  check_tls
  check_exposure
  printf '\nRingkasan: %d lolos, %d gagal, %d TODO\n' "$PASSED" "$FAILED" "$TODOS"
  if [ "$TODOS" -gt 0 ]; then
    echo "Masih ada $TODOS fungsi bertanda [TODO]. Lengkapi fungsinya, lalu jalankan lagi."
    exit 1
  fi
  if [ "$FAILED" -gt 0 ]; then
    echo "Ada pemeriksaan yang gagal. Perbaiki desainnya, lalu jalankan lagi."
    exit 1
  fi
  echo "Semua pemeriksaan lolos."
}

main "$@"
