#!/usr/bin/env bash
# =============================================================================
# Dijalankan SETIAP KALI Codespace / dev container menyala (postStartCommand),
# juga di awal post-create.sh. Aman dijalankan manual kapan saja:
#   bash .devcontainer/post-start.sh
#
# Latar belakang: Docker di dalam Codespace disediakan oleh fitur docker-in-docker.
# Saat Codespace dinyalakan lagi setelah berhenti (idle timeout atau Stop), skrip
# start milik fitur itu (versi 4.1.x) kadang gagal pada percobaan pertama, lalu
# menyalakan dockerd dengan containerd "cadangan" yang menyimpan image di folder
# lain. Gejalanya: "docker images" tiba-tiba kosong, container lab tidak bisa
# dinyalakan, dan build gagal dengan pesan "failed to extract layer".
#
# Skrip ini memeriksa keadaan itu dan, bila perlu, menyalakan ulang Docker dengan
# cara yang benar. Image dan data lab tidak dihapus. Bila Docker sudah benar,
# skrip ini tidak mengubah apa pun.
# =============================================================================
set -u

INIT=/usr/local/share/docker-init.sh          # skrip start milik fitur docker-in-docker
CONTAINERD_SOCK=/run/containerd/containerd.sock

# Hanya berlaku di dev container yang fitur docker-in-docker-nya memakai containerd
# terpisah (dockerd --containerd ...). Di tempat lain skrip ini langsung selesai.
[ -x "$INIT" ] || exit 0
[ -f /etc/containerd/config.toml ] || exit 0
grep -q -- '--containerd' "$INIT" 2>/dev/null || exit 0

as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

# benar    : dockerd memakai containerd utama (dockerd --containerd ...)
# cadangan : dockerd menyalakan containerd sendiri, image lab tampak hilang
# mati     : dockerd tidak berjalan
docker_state() {
  local args
  args="$(pgrep -a -x dockerd 2>/dev/null | head -n 1)"   # "PID dockerd argumen..."
  case "$args" in
    *--containerd*) echo benar ;;
    *dockerd*)      echo cadangan ;;
    *)              echo mati ;;
  esac
}

# Tunggu skrip start bawaan selesai bekerja (paling lama sekitar 1 menit):
# "docker info" berhasil dan dockerd yang sama masih hidup 2 detik kemudian.
# Bila proses dockerd sama sekali tidak ada selama 20 detik, tidak ada yang sedang
# menyalakannya, jadi tidak perlu menunggu lebih lama.
wait_settled() {
  local pid absent=0
  for _ in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
      pid="$(pgrep -x dockerd | head -n 1)"
      sleep 2
      if [ -n "$pid" ] && [ "$(pgrep -x dockerd | head -n 1)" = "$pid" ] && docker info >/dev/null 2>&1; then
        return 0
      fi
      absent=0
    else
      if pgrep -x dockerd >/dev/null; then absent=0; else absent=$((absent + 1)); fi
      [ "$absent" -ge 10 ] && return 1
      sleep 2
    fi
  done
  return 1
}

restart_docker() {
  as_root pkill -x dockerd 2>/dev/null
  as_root pkill -x containerd 2>/dev/null
  for _ in $(seq 1 20); do
    pgrep -x dockerd >/dev/null || pgrep -x containerd >/dev/null || break
    sleep 1
  done
  as_root pkill -9 -x dockerd 2>/dev/null
  as_root pkill -9 -x containerd 2>/dev/null
  # Socket sisa sesi sebelumnya membuat skrip start mengira containerd sudah siap.
  as_root rm -f "$CONTAINERD_SOCK" "$CONTAINERD_SOCK.ttrpc"
  as_root setsid "$INIT" >/dev/null 2>&1
  wait_settled
}

wait_settled
state="$(docker_state)"
[ "$state" = benar ] && exit 0

echo "== Docker di Codespace ini belum menyala dengan benar (keadaan: $state). Memperbaiki"
for attempt in 1 2 3; do
  restart_docker
  state="$(docker_state)"
  [ "$state" = benar ] && break
  echo "   percobaan $attempt belum berhasil (keadaan: $state)"
done

if [ "$state" = benar ]; then
  echo "== Docker sudah normal. Nyalakan lab dengan:  docker compose up -d --wait"
else
  echo "== Docker belum pulih (keadaan: $state). Stop lalu Start lagi Codespace ini,"
  echo "   kemudian jalankan:  bash .devcontainer/post-start.sh"
fi
exit 0
