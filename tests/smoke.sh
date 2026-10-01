#!/usr/bin/env bash
# =============================================================================
# smoke.sh: memastikan stack berjalan (dijalankan juga oleh GitHub Actions, job
# "stack", dan tetap harus lolos setelah tantangan desain dikerjakan).
#
#   docker compose up -d --build --wait
#   bash tests/smoke.sh
# =============================================================================
set -u
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
TEST_NAME="smoke"

require_stack

title "1. DNS internal Docker (dari toolbox)"
for svc in web api db; do
  ip="$(tb getent hosts "$svc" 2>/dev/null | awk 'NR == 1 { print $1 }')"
  if [ -n "$ip" ]; then pass "$svc -> $ip"; else fail "nama $svc tidak ter-resolve di toolbox"; fi
done

# Alamat dasar tes. Biasanya http://web. Bila Anda mengerjakan bonus "HTTP dialihkan
# ke HTTPS", nginx menjawab 301/302/307/308 ke https://..., lalu tes memakai
# https://web (-k: smoke test tidak memeriksa sertifikat, itu tugas challenge.sh).
BASE="http://web"
TLS_OPT=""
redirect="$(tb curl -s -o /dev/null --max-time 10 -w '%{http_code} %{redirect_url}' http://web/ 2>/dev/null | tr -d '\r')"
case "$redirect" in
  30[1278]\ https://*) BASE="https://web"; TLS_OPT="-k" ;;
esac

title "2. Frontend dan reverse proxy ($BASE)"
[ -n "$TLS_OPT" ] && info "http://web/ dialihkan ke ${redirect#* }, tes memakai $BASE"
# shellcheck disable=SC2086
tb_http "$BASE/" $TLS_OPT
if [ "$HTTP_CODE" = "200" ] && printf '%s' "$HTTP_BODY" | grep -q "Net Web Lab"; then
  pass "GET / -> 200, halaman Net Web Lab"
else
  fail "GET / -> $HTTP_CODE (halaman frontend tidak tampil)"
fi

# shellcheck disable=SC2086
tb_http "$BASE/api/health" $TLS_OPT
if [ "$HTTP_CODE" = "200" ] && printf '%s' "$HTTP_BODY" | jqx -e '.status == "ok" and .db == "up"' >/dev/null 2>&1; then
  pass "GET /api/health -> 200, status ok, db up"
else
  fail "GET /api/health -> $HTTP_CODE"
  hint "cek: docker compose logs api db"
  if [ "$HTTP_CODE" = "503" ]; then
    hint "baru mengubah bagian networks: di compose.yaml? jalankan: docker compose up -d --force-recreate --wait"
  fi
fi

# shellcheck disable=SC2086
tb_http "$BASE/api/whoami" $TLS_OPT
if [ "$HTTP_CODE" = "200" ] && printf '%s' "$HTTP_BODY" | jqx -e '.viaProxy == true and (.headers["x-real-ip"] | length > 0)' >/dev/null 2>&1; then
  pass "GET /api/whoami lewat nginx membawa X-Forwarded-For dan X-Real-IP"
else
  fail "GET /api/whoami -> $HTTP_CODE, header proxy tidak lengkap"
  hint "cek proxy_set_header di web/nginx/snippets/lab-locations.conf"
fi

# shellcheck disable=SC2086
tb_http "$BASE/student.json" $TLS_OPT
if [ "$HTTP_CODE" = "200" ] && printf '%s' "$HTTP_BODY" | jqx -e 'type == "object"' >/dev/null 2>&1; then
  pass "GET /student.json -> 200 (JSON)"
else
  fail "GET /student.json -> $HTTP_CODE"
fi

title "3. Data lewat tiga tier (POST lalu GET /api/notes)"
note="smoke test $(date +%s)"
# shellcheck disable=SC2086
headers="$(tb curl -s $TLS_OPT --max-time 10 -o /dev/null -D - -X POST -H 'Content-Type: application/json' \
  -d "{\"text\": \"$note\"}" "$BASE/api/notes" 2>/dev/null | tr -d '\r')"
status_line="$(printf '%s\n' "$headers" | head -n 1)"
location="$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1) == "location" { print $2 }')"
if printf '%s' "$status_line" | grep -q ' 201' && [ -n "$location" ]; then
  pass "POST /api/notes -> 201, Location: $location"
  # shellcheck disable=SC2086
  tb_http "$BASE$location" $TLS_OPT
  if [ "$HTTP_CODE" = "200" ] && printf '%s' "$HTTP_BODY" | jqx -e --arg t "$note" '.text == $t' >/dev/null 2>&1; then
    pass "GET $location -> 200, isi catatan sama"
  else
    fail "GET $location -> $HTTP_CODE"
  fi
else
  fail "POST /api/notes gagal: ${status_line:-tidak ada jawaban}"
fi

# shellcheck disable=SC2086
tb_http "$BASE/api/notes/999999999" $TLS_OPT
if [ "$HTTP_CODE" = "404" ]; then pass "GET /api/notes/999999999 -> 404"; else fail "catatan yang tidak ada -> $HTTP_CODE (harusnya 404)"; fi

# shellcheck disable=SC2086
tb_http "$BASE/api/notes" $TLS_OPT -X POST -H 'Content-Type: application/json' -d '{bukan json'
if [ "$HTTP_CODE" = "400" ]; then pass "POST JSON rusak -> 400"; else fail "POST JSON rusak -> $HTTP_CODE (harusnya 400)"; fi

title "4. Dari host (port yang dipublish service web)"
published="$(docker compose port web 80 2>/dev/null | tr -d '\r' | head -n 1)"
if [ -z "$published" ]; then
  fail "service web tidak mem-publish port 80"
  hint "compose.yaml, service web: ports: - \"8080:80\""
else
  port="${published##*:}"
  host_http "http://127.0.0.1:$port/api/health"
  case "$HOST_CODE $HOST_REDIRECT" in
    200\ *)              pass "http://127.0.0.1:$port/api/health -> 200" ;;
    30[1278]\ https://*) pass "http://127.0.0.1:$port/api/health -> $HOST_CODE, dialihkan ke $HOST_REDIRECT" ;;
    *)                   fail "http://127.0.0.1:$port/api/health -> $HOST_CODE" ;;
  esac
fi

finish
