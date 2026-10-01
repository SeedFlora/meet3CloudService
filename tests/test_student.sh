#!/usr/bin/env bash
# =============================================================================
# test_student.sh: memeriksa student.json (dijalankan juga oleh GitHub Actions,
# job "student").
#   bash tests/test_student.sh
#
# Syarat lolos: JSON valid, field name/class/github terisi dan bukan contoh,
# username GitHub valid, dan TIDAK ada NIM (repo ini publik).
# =============================================================================
set -u
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
TEST_NAME="test_student"

title "Memeriksa student.json"

if [ ! -f student.json ]; then
  fail "student.json tidak ditemukan di root repo"
  finish
fi

if ! jq_available; then
  fail "jq tidak tersedia untuk membaca JSON"
  hint "install jq (sudo apt-get install -y jq), atau nyalakan stack lalu ulangi"
  finish
fi

if ! jqx -e 'type == "object"' < student.json >/dev/null 2>&1; then
  fail "student.json bukan JSON object yang valid"
  hint 'cek tanda kutip dan koma, contoh: {"name": "...", "class": "...", "github": "..."}'
  finish
fi
pass "student.json adalah JSON valid"

field() {
  jqx -r --arg k "$1" 'if (.[$k] | type) == "string" then .[$k] else "" end' < student.json | tr -d '\r'
}
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

check_field() {  # check_field KEY CONTOH
  local value
  value="$(trim "$(field "$1")")"
  if [ -z "$value" ]; then
    fail "field \"$1\" kosong atau bukan teks"
  elif [ "$value" = "$2" ]; then
    fail "field \"$1\" masih berisi contoh (\"$2\")"
    hint "ganti dengan data Anda, commit, lalu push"
  else
    pass "field \"$1\" terisi: $value"
  fi
}
check_field name   "Nama Lengkap Anda"
check_field class  "Kode Kelas"
check_field github "username-github"

github="$(trim "$(field github)")"
if [ -n "$github" ] && [ "$github" != "username-github" ]; then
  if [[ "$github" =~ ^[A-Za-z0-9]([A-Za-z0-9]|-[A-Za-z0-9])*$ ]] && [ "${#github}" -le 39 ]; then
    pass "username GitHub valid: $github"
  else
    fail "username GitHub tidak valid: \"$github\""
    hint "tulis username saja (huruf, angka, tanda minus), tanpa @ dan tanpa URL"
  fi
fi

nim_keys="$(jqx -r '[paths | .[-1] | strings | select(test("^nim$"; "i"))] | length' < student.json | tr -d '\r')"
nim_like="$(jqx -r '[.. | strings | select(test("[0-9]{10}"))] | length' < student.json | tr -d '\r')"
if [ "${nim_keys:-0}" -gt 0 ] || [ "${nim_like:-0}" -gt 0 ]; then
  fail "student.json berisi NIM (atau angka mirip NIM)"
  hint "hapus NIM: repo dan halaman web ini bisa dilihat publik"
else
  pass "tidak ada NIM di student.json"
fi

finish
