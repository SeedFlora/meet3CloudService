# shellcheck shell=bash
# =============================================================================
# Helper bersama untuk tests/*.sh. File ini di-"source", bukan dijalankan langsung.
# Cukup bash + docker compose; jq dipakai dari host bila ada, bila tidak ada
# dipakai jq di dalam container toolbox.
# =============================================================================

export MSYS_NO_PATHCONV=1   # Git Bash (Windows): jangan ubah argumen /lab/... menjadi C:/...

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

if [ -t 1 ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
  C_OK=$'\033[32m'; C_BAD=$'\033[31m'; C_DIM=$'\033[2m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else
  C_OK=''; C_BAD=''; C_DIM=''; C_B=''; C_0=''
fi

N_PASS=0
N_FAIL=0
pass()  { N_PASS=$((N_PASS + 1)); printf '  %sPASS%s  %s\n' "$C_OK" "$C_0" "$*"; }
fail()  { N_FAIL=$((N_FAIL + 1)); printf '  %sFAIL%s  %s\n' "$C_BAD" "$C_0" "$*"; }
info()  { printf '  %sinfo%s  %s\n' "$C_DIM" "$C_0" "$*"; }
hint()  { printf '        %s-> %s%s\n' "$C_DIM" "$*" "$C_0"; }
title() { printf '\n%s%s%s\n' "$C_B" "$*" "$C_0"; }

# Cetak ringkasan lalu keluar: kode 0 bila tidak ada FAIL, kode 1 bila ada.
finish() {
  printf '\n%s%s: %d PASS, %d FAIL%s\n' "$C_B" "${TEST_NAME:-test}" "$N_PASS" "$N_FAIL" "$C_0"
  if [ "$N_FAIL" -eq 0 ]; then exit 0; else exit 1; fi
}

# service_running NAMA: sukses bila container service tersebut sedang berjalan
service_running() {
  docker compose ps --status running --services 2>/dev/null | tr -d '\r' | grep -qx "$1"
}

# tb PERINTAH...: jalankan perintah di dalam toolbox (tanpa TTY, aman untuk skrip/CI)
tb() { docker compose exec -T toolbox "$@"; }

jq_available() { command -v jq >/dev/null 2>&1 || service_running toolbox; }

# jqx ARGUMEN...: jq di host bila ada, bila tidak ada pakai jq di toolbox
jqx() {
  if command -v jq >/dev/null 2>&1; then
    jq "$@"
  elif service_running toolbox; then
    docker compose exec -T toolbox jq "$@"
  else
    echo "jq tidak ditemukan. Install jq atau nyalakan stack (docker compose up -d)." >&2
    return 127
  fi
}

# tb_http URL [ARGUMEN curl...]: curl dari toolbox, hasil di HTTP_CODE dan HTTP_BODY
tb_http() {
  local out
  out="$(tb curl -s --max-time 10 -w '\n%{http_code}' "$@" 2>/dev/null)" || true
  HTTP_CODE="${out##*$'\n'}"
  HTTP_BODY="${out%$'\n'*}"
  [ -n "$HTTP_CODE" ] || HTTP_CODE="000"
}

# host_http URL [ARGUMEN curl...]: curl dari host (bukan dari toolbox); hasil di
# HOST_CODE dan HOST_REDIRECT. Body ditampung di variabel, bukan "-o /dev/null":
# di Git Bash (Windows) curl tidak bisa menulis ke /dev/null saat MSYS_NO_PATHCONV=1.
host_http() {
  local out last
  out="$(curl -s --max-time 10 -w '\n%{http_code} %{redirect_url}' "$@" 2>/dev/null)" || true
  last="${out##*$'\n'}"
  HOST_CODE="${last%% *}"
  HOST_REDIRECT="${last#* }"
  [ -n "$HOST_CODE" ] || HOST_CODE="000"
}

# host_port_open HOST PORT: sukses bila port TCP di host bisa dihubungi (maks 3 detik).
# Utamakan /dev/tcp milik bash (sama di Linux, Codespaces, dan Git Bash); nc dipakai
# bila perintah timeout tidak ada (misalnya macOS).
host_port_open() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" >/dev/null 2>&1
  elif command -v nc >/dev/null 2>&1; then
    nc -z -w 3 "$1" "$2" >/dev/null 2>&1
  else
    bash -c "exec 3<>/dev/tcp/$1/$2" >/dev/null 2>&1
  fi
}

# require_stack: hentikan tes dengan pesan jelas bila stack belum berjalan
require_stack() {
  if ! docker compose version >/dev/null 2>&1; then
    fail "docker compose tidak tersedia"
    hint "jalankan tes ini di Codespaces atau di mesin yang sudah terpasang Docker"
    finish
  fi
  local missing=""
  for svc in web api db toolbox; do
    service_running "$svc" || missing="$missing $svc"
  done
  if [ -n "$missing" ]; then
    fail "service belum berjalan:$missing"
    hint "nyalakan dulu: docker compose up -d --build --wait"
    hint "lihat penyebabnya: docker compose ps -a  dan  docker compose logs <service>"
    finish
  fi
}
