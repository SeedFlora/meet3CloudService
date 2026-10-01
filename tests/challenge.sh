#!/usr/bin/env bash
# =============================================================================
# challenge.sh: memeriksa TANTANGAN DESAIN (dijalankan oleh GitHub Actions, job
# "challenge"). Sengaja GAGAL (merah) pada repo awal dan baru lolos (hijau)
# setelah desainnya Anda perbaiki.
#
#   bash scripts/make-cert.sh
#   docker compose up -d --build --wait
#   bash tests/challenge.sh
#
# Yang diperiksa:
#   A. compose.yaml: hanya web yang mem-publish port, web mem-publish 443,
#      web dan db tidak berada di jaringan yang sama
#   B. sertifikat web/certs/lab.crt: ada, SAN benar, masih berlaku
#   C. HTTPS dari toolbox: curl --cacert dan openssl s_client (Verify return code 0)
#   D. exposure: port 3000 dan 5432 tidak bisa dihubungi dari host
#   E. segmentasi: container web tidak bisa menghubungi db:5432, baik lewat nama,
#      IP, maupun host Docker (port yang dipublish bisa dimasuki dari jaringan lain)
#   F. scripts/healthcheck.sh keluar dengan kode 0 (minimal 10 pemeriksaan lolos)
# =============================================================================
set -u
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
TEST_NAME="challenge"

# --- A. Desain di compose.yaml --------------------------------------------------
title "A. Desain di compose.yaml (docker compose config)"
if ! CONFIG="$(docker compose config --format json 2>&1)"; then
  fail "compose.yaml tidak valid"
  printf '%s\n' "$CONFIG" | sed 's/^/        /'
  finish
fi
# Tanpa jq di host, jq di toolbox yang dipakai, jadi stack harus sudah menyala.
command -v jq >/dev/null 2>&1 || require_stack

publishers="$(printf '%s' "$CONFIG" | jqx -r '.services | to_entries[] | select((.value.ports // []) | length > 0) | .key' | tr -d '\r' | sort | xargs)"
if [ "$publishers" = "web" ]; then
  pass "hanya service web yang mem-publish port ke host"
else
  fail "service yang mem-publish port ke host: ${publishers:-(tidak ada)} (seharusnya hanya web)"
  for svc in $publishers; do
    [ "$svc" = "web" ] && continue
    ports="$(printf '%s' "$CONFIG" | jqx -r --arg s "$svc" '[.services[$s].ports[] | "\(.published // "?"):\(.target)"] | join(", ")' | tr -d '\r')"
    hint "$svc mem-publish $ports: hapus bagian ports: dari service $svc"
  done
fi

HTTPS_HOST_PORT="$(printf '%s' "$CONFIG" | jqx -r '[.services.web.ports // [] | .[] | select(.target == 443) | .published // empty] | first // empty' | tr -d '\r')"
if [ -n "$HTTPS_HOST_PORT" ]; then
  pass "web mem-publish HTTPS: host $HTTPS_HOST_PORT -> container 443"
else
  fail "web belum mem-publish port 443 (HTTPS)"
  hint "compose.yaml, service web: ports: tambahkan \"8443:443\""
fi

shared="$(printf '%s' "$CONFIG" | jqx -r '
  def nets(s): (.services[s].networks // {"default": null}) | keys;
  nets("web") as $w | [nets("db")[] | select(. as $n | $w | index($n))] | join(", ")' | tr -d '\r')"
if [ -z "$shared" ]; then
  pass "web dan db tidak berada di jaringan yang sama (segmentasi)"
else
  fail "web dan db sama-sama terhubung ke jaringan: $shared"
  hint "db cukup berada di jaringan data (hanya api yang perlu menghubungi db)"
fi

internal="$(printf '%s' "$CONFIG" | jqx -r '[.networks // {} | to_entries[] | select(.value.internal == true) | .key] | join(", ")' | tr -d '\r')"
if [ -n "$internal" ]; then info "bonus: jaringan internal (tanpa akses Internet): $internal"; else info "bonus (opsional): jadikan jaringan data internal: true"; fi

# Pemeriksaan B sampai F membutuhkan stack yang sedang berjalan.
require_stack

# --- B. Sertifikat --------------------------------------------------------------
title "B. Sertifikat web/certs/lab.crt"
if [ -s web/certs/lab.crt ] && [ -s web/certs/lab.key ]; then
  pass "web/certs/lab.crt dan lab.key ada"
  san="$(tb openssl x509 -in /lab/web/certs/lab.crt -noout -ext subjectAltName 2>/dev/null | tr -d '\r' | tail -n +2 | xargs)"
  missing=""
  for want in "DNS:localhost" "DNS:web" "IP Address:127.0.0.1"; do
    case "$san" in *"$want"*) ;; *) missing="$missing [$want]" ;; esac
  done
  if [ -z "$missing" ]; then pass "SAN sertifikat: $san"; else fail "SAN sertifikat belum memuat:$missing"; hint "buat ulang: bash scripts/make-cert.sh"; fi
  if tb openssl x509 -in /lab/web/certs/lab.crt -noout -checkend 604800 >/dev/null 2>&1; then
    pass "sertifikat masih berlaku minimal 7 hari lagi"
  else
    fail "sertifikat kedaluwarsa atau berakhir dalam 7 hari"
    hint "buat ulang: bash scripts/make-cert.sh"
  fi
else
  fail "sertifikat belum ada (web/certs/lab.crt dan lab.key)"
  hint "buat dengan: bash scripts/make-cert.sh"
fi

# --- C. HTTPS dari dalam jaringan -------------------------------------------------
title "C. HTTPS dari toolbox (https://web)"
tb_http https://web/api/health --cacert /lab/web/certs/lab.crt
if [ "$HTTP_CODE" = "200" ]; then
  pass "curl --cacert lab.crt https://web/api/health -> 200"
else
  fail "curl --cacert lab.crt https://web/api/health -> $HTTP_CODE"
  case "$HTTP_CODE" in
    50[234])
      hint "HTTPS sudah menjawab, tetapi api atau db bermasalah: docker compose ps, lalu docker compose logs api"
      hint "baru mengubah bagian networks: di compose.yaml? jalankan: docker compose up -d --force-recreate --wait"
      ;;
    *)
      hint "aktifkan web/nginx/https.conf (salin dari https.conf.example), lalu: docker compose up -d --wait"
      ;;
  esac
fi

tls="$(tb sh -c 'openssl s_client -connect web:443 -servername web -CAfile /lab/web/certs/lab.crt -verify_hostname web </dev/null 2>/dev/null' | tr -d '\r')"
verify="$(printf '%s\n' "$tls" | grep -m1 'Verify return code' | sed 's/^ *//')"
proto="$(printf '%s\n' "$tls" | grep -m1 -E '^ *Protocol *:|^New, TLS' | sed 's/^ *//')"
if printf '%s' "$verify" | grep -q 'Verify return code: 0 (ok)'; then
  pass "openssl s_client -verify_hostname web: $verify"
  [ -n "$proto" ] && info "$proto"
else
  fail "openssl s_client ke web:443: ${verify:-tidak ada koneksi TLS}"
fi

# --- D. Exposure dari host --------------------------------------------------------
title "D. Exposure: port yang bisa dihubungi dari host"
if [ -n "$HTTPS_HOST_PORT" ]; then
  host_http "https://127.0.0.1:$HTTPS_HOST_PORT/api/health" -k
  if [ "$HOST_CODE" = "200" ]; then pass "https://127.0.0.1:$HTTPS_HOST_PORT/api/health -> 200 (dari host)"; else fail "https://127.0.0.1:$HTTPS_HOST_PORT/api/health -> $HOST_CODE (dari host)"; fi
fi
for port in 3000 5432; do
  if host_port_open 127.0.0.1 "$port"; then
    fail "port $port terbuka di host (127.0.0.1:$port)"
    hint "hapus publish port $port di compose.yaml (atau hentikan aplikasi lain yang memakai port itu)"
  else
    pass "port $port tertutup di host"
  fi
  if tb nc -z -w 3 host.docker.internal "$port" >/dev/null 2>&1; then
    fail "port $port terbuka bila dilihat dari toolbox lewat host.docker.internal"
  else
    pass "port $port tertutup dari toolbox lewat host.docker.internal"
  fi
done

# --- E. Segmentasi jaringan ---------------------------------------------------------
title "E. Segmentasi: container web tidak boleh menghubungi db"
# Tiga jalur dicoba dari dalam container web: nama "db", IP db, dan host Docker
# (gateway container web). Port yang dipublish bisa dimasuki container dari jaringan
# mana pun lewat host, jadi mem-publish 5432 ikut melubangi segmentasi.
web_can() { docker compose exec -T web nc -z -w 2 "$1" 5432 >/dev/null 2>&1; }
db_id="$(docker compose ps -q db | tr -d '\r')"
db_ips="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$db_id" 2>/dev/null | tr -d '\r' | xargs)"
web_gw="$(docker compose exec -T web sh -c "ip route | awk '/^default/ { print \$3; exit }'" 2>/dev/null | tr -d '\r')"
by_name=""; by_ip=""; by_host=""
web_can db && by_name="db"
for ip in $db_ips; do web_can "$ip" && by_ip="$by_ip $ip"; done
[ -n "$web_gw" ] && web_can "$web_gw" && by_host="$web_gw"
if [ -z "$by_name$by_ip$by_host" ]; then
  pass "web tidak bisa membuka koneksi ke db:5432 (dicoba: db, $db_ips, host ${web_gw:-?})"
else
  fail "web BISA membuka koneksi ke port 5432:${by_name:+ lewat nama db;}${by_ip:+ lewat IP$by_ip;}${by_host:+ lewat host $by_host}"
  [ -n "$by_name" ] && hint "db berada di jaringan yang juga dipakai web: db cukup di jaringan data"
  [ -n "$by_host" ] && hint "db mem-publish 5432: container di jaringan mana pun bisa masuk lewat host Docker ($by_host)"
  [ -z "$by_name" ] && [ -n "$by_ip" ] && hint "IP db terjangkau dari jaringan lain (terjadi di Docker Desktop selama 5432 dipublish)"
fi

# --- F. healthcheck.sh ----------------------------------------------------------
title "F. scripts/healthcheck.sh (dijalankan di toolbox)"
hc_out="$(docker compose exec -T -e HTTPS_PORT="${HTTPS_HOST_PORT:-8443}" toolbox bash scripts/healthcheck.sh 2>&1)"
hc_rc=$?
hc_out="$(printf '%s' "$hc_out" | tr -d '\r')"
printf '%s\n' "$hc_out" | sed 's/^/        | /'
hc_ok="$(printf '%s\n' "$hc_out" | sed -n 's/^Ringkasan: \([0-9][0-9]*\) lolos.*/\1/p' | tail -n 1)"
if [ "$hc_rc" -eq 0 ] && [ "${hc_ok:-0}" -ge 10 ]; then
  pass "healthcheck.sh keluar dengan kode 0 ($hc_ok pemeriksaan lolos)"
elif [ "$hc_rc" -eq 0 ]; then
  fail "healthcheck.sh keluar dengan kode 0 tetapi hanya ${hc_ok:-0} pemeriksaan lolos (minimal 10)"
else
  fail "healthcheck.sh keluar dengan kode $hc_rc"
  hint "lengkapi fungsi check_* yang masih [TODO] / perbaiki yang [GAGAL]"
fi

finish
