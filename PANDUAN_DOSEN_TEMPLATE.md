# Panduan dosen - Lab 03 Networking & Web Services

**COMP6991031 | Pertemuan 3 | 120 menit**
Repo kelas: [SeedFlora/meet3CloudService](https://github.com/SeedFlora/meet3CloudService) (**Public template**). Materi pendamping: [modul mahasiswa](MODUL_MAHASISWA.md), [panduan Git](PANDUAN_GIT.md), dan [template laporan](hasil/TEMPLATE_LAPORAN.md).

## Hasil belajar dan batas latihan

Mahasiswa menelusuri request browser -> nginx (`web`) -> Node API (`api`) -> PostgreSQL (`db`) dalam aplikasi empat container; memakai `dig`, `nslookup`, `ping`, `traceroute`, `curl`, `wget`, `nmap`, `nc`, dan `openssl`; mengidentifikasi port yang terpapar; lalu mengaktifkan HTTPS dan membatasi publikasi port tanpa merusak komunikasi antartier. Pemindaian hanya untuk **service lab milik mahasiswa sendiri**.

Lab ini pengantar desain multi-tier. Docker Compose dipakai sebagai lingkungan konsisten, sedangkan detail container dibahas di Lab 04-06. Pekerjaan kode mahasiswa berada di `compose.yaml`, `web/nginx/https.conf`, dan lima fungsi TODO pada `scripts/healthcheck.sh`. Mereka tidak perlu membuat frontend/backend baru.

![Codespaces live: frontend empat tier di port 8080](screenshots/lab03_codespaces_web_live.jpg)

*Langkah UI demo: buka port 8080 dari panel **Ports** Codespaces. Browser meminta halaman ke nginx; JavaScript meminta `/api/health`, nginx meneruskan ke API, lalu API mengecek PostgreSQL. Tunjuk empat status hijau. Label `443 -> 80` adalah forwarding HTTPS browser ke HTTP nginx starter, belum TLS nginx.*

## Persiapan dosen

1. Pastikan repo kelas menampilkan **Public template** dan tombol **Use this template**. Minta mahasiswa membuat repo pribadi dari template, lalu membuat Codespace dari repo masing-masing. Jalur cadangan: Docker Desktop/Engine lokal, Compose plugin, dan Git Bash/WSL di Windows.
2. Pastikan root repo mahasiswa memuat `.devcontainer/`, `.github/workflows/`, `compose.yaml`, `MODUL_MAHASISWA.md`, dan `screenshots/`. Tunggu `postCreateCommand` Codespaces selesai. Jika pull image terputus, ulangi `docker compose up -d --build --wait`.
3. Cek Docker dan port host 8080, 3000, 5432. Bila port bentrok, hentikan service lokal yang memakainya. Siapkan repo demo terpisah tanpa data pribadi.
4. Tampilkan panel **Ports** Codespaces. Gunakan visibilitas **Private** untuk port praktik. Port 8443 memakai sertifikat self-signed, sehingga browser mungkin memberi peringatan.

Terangkan status Actions awal: `stack` dirancang hijau; `student` merah selama `student.json` masih contoh; `challenge` **sengaja merah** sebelum tugas selesai.

## Rencana kelas 120 menit

| Waktu | Kegiatan | Bukti mahasiswa |
|---|---|---|
| 0-10 menit | Uraikan browser -> web -> API -> DB; buat repo pribadi dan Codespace/clone lokal. | URL repo dan terminal di root. |
| 10-25 menit | Preflight, hidupkan stack, buka web, jalankan smoke. | `docker compose ps`, port 8080, `smoke.sh`. |
| 25-45 menit | DNS dan konektivitas dari toolbox; bahas `localhost` host vs container. | `dig`, `nslookup`, `ping`/`traceroute`. |
| 45-65 menit | HTTP 200/201/404/400, header proxy, dan `wget`. | Output `curl -i`, perbandingan `viaProxy`. |
| 65-80 menit | Pindai hanya stack sendiri; jalankan challenge awal. | `nmap`/`nc`, port host awal, challenge merah. |
| 80-105 menit | Sertifikat, HTTPS, segmentasi, dan fungsi healthcheck. | TLS, port akhir, `healthcheck.sh`. |
| 105-120 menit | Uji ulang, laporan, cek staged diff, commit/push, lihat Actions. | Repo/commit, screenshot pribadi, CI. |

Jika sesi 90 menit, kerjakan checkpoint 1-4 di kelas dan lanjutkan checkpoint 5 beserta laporan sebagai tugas. Tetap kumpulkan bukti port **sebelum dan sesudah** perubahan.

## Demo dan checkpoint

### 1. Stack awal dan alur request

Dari root repo demo:

```bash
docker compose version
docker compose config -q
docker compose up -d --build --wait
docker compose ps
bash tests/smoke.sh
```

Tunjukkan `web`, `api`, `db` sehat serta `toolbox` berjalan. Pada paket uji lokal, smoke awal memberi **12 PASS, 0 FAIL**. Buka port 8080 pada panel **Ports** Codespaces atau `http://localhost:8080` secara lokal. Kolom `PORTS` starter memperlihatkan web, API, dan DB mem-publish port host.

![Status awal Docker Compose: port web, API, dan database dipublish](screenshots/lab03_docker_ps_lokal.png)

*Perintah: `docker compose ps`. Compose meminta status runtime dan port publish dari Docker Engine. Tunjuk `healthy` pada web/API/DB, `running` pada toolbox, serta mapping host 8080/3000/5432 pada starter. Minta mahasiswa membandingkan output mereka, bukan menyalin gambar.*

Gambar berikut adalah hasil **uji live di GitHub Codespaces**: empat service berjalan dan smoke **12 PASS, 0 FAIL**. Halaman web di pembuka menampilkan empat tier aktif. Pakai ini untuk menunjukkan bahwa jalur Codespaces sungguh dapat menjalankan stack. Tautan browser Codespaces dapat memakai HTTPS karena port forwarding GitHub; itu **belum membuktikan** nginx starter telah mengaktifkan TLS. Bukti tantangan adalah `https://web` dari toolbox dengan `--cacert` dan sertifikat yang diperiksa OpenSSL.

![Codespaces live: terminal Compose dan smoke test](screenshots/lab03_codespaces_docker_live.jpg)

*Perintah live: `docker compose ps --format '{{.Service}} {{.State}} {{.Health}}'` lalu `bash tests/smoke.sh`. Perintah pertama merangkum empat container; smoke meminta DNS, halaman, API, POST/GET DB, dan akses host. Tunjuk `smoke: 12 PASS, 0 FAIL` di terminal; mahasiswa wajib menunjukkan output repo sendiri.*

### 2. DNS dan konektivitas internal

```bash
docker compose exec toolbox bash
dig web A
nslookup api
getent hosts db
ping -c 3 web
traceroute -m 5 web
```

Minta mahasiswa menyebut **nama service, IP internal, jaringan, dan posisi terminal**. `web` dan `api` dapat punya lebih dari satu IP karena terhubung ke beberapa jaringan. `localhost` di toolbox menunjuk toolbox, bukan laptop. Jika ICMP dibatasi, gunakan TCP/HTTP sebagai pembuktian tambahan dan catat batasannya.

![Contoh DNS dan ping dari toolbox](screenshots/lab03_dns_toolbox.png)

*Perintah: `dig web A`, `nslookup api`, dan `ping -c 3 web` dari toolbox. DNS Compose mengubah nama service menjadi IP internal; ping menguji ICMP. Tunjuk alamat `172.28.x.x` dan jumlah paket diterima/loss.*

![Codespaces live: DNS, ping, dan traceroute dari toolbox](screenshots/lab03_codespaces_network_live.jpg)

*Perintah live: `docker compose exec toolbox bash`, kemudian `dig +short web`, `nslookup api`, `ping -c 1 web`, dan `traceroute -m 3 web`. Jelaskan bahwa alat berjalan di jaringan container; tunjuk IP web/API, `0% packet loss`, dan hop menuju web.*

### 3. HTTP dan reverse proxy

Masih di toolbox:

```bash
curl -i http://web/api/health
curl -i http://web/api/whoami
curl -i http://web/api/notes/999999999
curl -i -X POST http://web/api/notes -H 'Content-Type: application/json' -d '{"text":"catatan kelas"}'
wget -qO- http://web/api/health
```

Tunjukkan status dan header sebelum body JSON. Health memberi 200 dan `db: up`; catatan yang tidak ada 404; POST valid 201 dengan `Location`. Untuk 400, kirim JSON rusak atau lihat smoke test. Bandingkan `curl -i` (header dan body) dengan `wget -qO-` (body). Dari host, bandingkan request ke 8080 melalui nginx dengan 3000 langsung ke API dan field `viaProxy`.

Pada uji browser **Codespaces live**, form frontend berhasil menyimpan catatan baru dan menampilkan `201 Created`; daftar serta hitungan catatan PostgreSQL bertambah. Gunakan observasi ini untuk menunjukkan POST browser -> nginx -> API -> DB. Screenshot area bawah web tidak disertakan karena memuat alamat IP klien.

![Contoh respons 200 dan 404 melalui nginx](screenshots/lab03_http_toolbox.png)

*Perintah: `curl -i http://web/api/health` dan `curl -i http://web/api/notes/999999999`. Curl menampilkan status/header/body dari nginx dan API. Tunjuk `200` dengan `db: up` serta `404` untuk ID tak ada; hubungkan POST valid ke `201` dan `Location`.*

### 4. Port dan challenge awal

```bash
nmap -sT -Pn -p 8080,3000,5432 host.docker.internal
nc -vz -w 2 host.docker.internal 5432
exit
bash tests/challenge.sh
```

Challenge starter sengaja gagal. Contoh paket uji awal menunjukkan **1 PASS, 11 FAIL**; jumlah bisa berbeda menurut kondisi mesin. Bahas beda port yang dipublish ke host dengan koneksi internal jaringan `app`/`data`.

![Port host starter terdeteksi oleh nmap](screenshots/lab03_port_awal.png)

*Perintah: `nmap -sT -Pn -p 8080,3000,5432 host.docker.internal`. Toolbox mencoba koneksi TCP ke host Docker. Tunjuk tiga status `open` dan cocokkan dengan mapping pada `docker compose ps`; target pemindaian hanya lab sendiri.*

![Codespaces live: curl, wget, nmap, nc, dan OpenSSL dari toolbox](screenshots/lab03_codespaces_http_ports_live.jpg)

*Perintah live: `curl` mengambil status health, `wget -qO-` mengambil JSON, `nmap` membaca port host, `nc -vz api 3000` menguji satu socket, dan `openssl version` memeriksa alat TLS. Tunjuk `HTTP 200`, `db: up`, port 3000/5432/8080 `open`, dan koneksi API `succeeded` sebagai dasar perubahan desain.*

![Contoh challenge starter yang memang belum lulus](screenshots/lab03_challenge_awal.png)

*Perintah: `bash tests/challenge.sh`. Skrip membandingkan desain Compose, sertifikat, HTTPS, exposure, segmentasi, dan healthcheck dengan sasaran lab. Tunjuk `FAIL` beserta hint sebagai diagnosis awal; bukan error platform. Jalankan ulang setelah tugas untuk membuktikan semua lulus.*

### 5. TLS dan perubahan desain

Minta mahasiswa membuat sertifikat dengan `bash scripts/make-cert.sh`, menyalin `web/nginx/https.conf.example` ke `web/nginx/https.conf`, dan mengubah `compose.yaml` agar hanya `web` mem-publish port host 8080/8443. `web` <-> `api` tetap di jaringan `app`; `api` <-> `db` tetap di `data`. `web` tidak perlu berbagi jaringan langsung dengan `db`. Mahasiswa melengkapi `check_dns`, `check_tcp`, `check_http`, `check_tls`, dan `check_exposure` di `scripts/healthcheck.sh`; komentar TODO adalah petunjuk. Jangan bagikan file solusi penuh.

```bash
docker compose up -d --force-recreate --wait
docker compose exec toolbox curl --cacert /lab/web/certs/lab.crt https://web/api/health
docker compose exec toolbox openssl x509 -in /lab/web/certs/lab.crt -noout -subject -issuer -dates -ext subjectAltName
docker compose exec toolbox bash scripts/healthcheck.sh
bash tests/smoke.sh
bash tests/challenge.sh
docker compose ps
```

Sasaran: HTTPS menjawab 200 dengan `--cacert`; sertifikat memuat SAN `web` dan masih berlaku; smoke hijau; healthcheck keluar 0 dengan minimal 10 pemeriksaan lolos; challenge hijau (contoh paket uji **15 PASS, 0 FAIL**). Hanya `web` mem-publish port host. API/DB tetap berjalan pada jaringan internal.

Hasil acuan dari uji end-to-end **lokal** pada paket ini: starter empat service berjalan, smoke **12/0**, challenge awal **1/11**; setelah penyelesaian sementara, smoke **12/0**, healthcheck **16/0**, challenge **15/0**, verifikasi OpenSSL **0 (ok), TLS 1.3**, dan hanya host 8080/8443 terbuka. Starter juga diuji **live di Codespaces SeedFlora** dengan empat service sehat dan smoke **12/0**. File solusi sementara tidak disertakan pada repo template. Akses dan kuota Codespaces setiap akun mahasiswa tetap perlu dicek.

![Contoh bagian atas web sesudah HTTPS aktif](screenshots/lab03_web_https_target_top.png)

*Perintah: `docker compose up -d --force-recreate --wait`, lalu `docker compose exec toolbox curl --cacert /lab/web/certs/lab.crt https://web/api/health`. Curl memverifikasi sertifikat lab serta koneksi nginx:443 dan harus memberi 200. Saat membuka `https://localhost:8443` lokal, tunjuk label 8443 -> 443, badge HTTPS, dan empat tier hijau; browser dapat memperingatkan sertifikat self-signed.*

![Contoh form HTTPS menyimpan catatan dengan status 201](screenshots/lab03_web_https_target_post.png)

*Langkah UI: isi form **Tulis catatan** dan klik **Simpan catatan**. Browser mengirim POST `/api/notes` melalui nginx ke API; API menulis ke PostgreSQL. Tunjuk `201 Created` dan catatan baru sebagai bukti jalur tulis tiga tier tetap berfungsi setelah TLS/segmentasi.*

![Contoh Compose akhir: hanya web mem-publish port host](screenshots/lab03_docker_target.png)

*Perintah pada gambar: `docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'` setelah Compose direcreate. Tunjuk `web` mem-publish 8080 -> 80 dan 8443 -> 443, sedangkan API/DB hanya port internal dan tetap healthy. Bandingkan dengan nmap awal serta `bash tests/smoke.sh` dan `bash tests/challenge.sh` akhir. Gambar target berasal dari salinan uji, bukan bukti mahasiswa.*

## Penilaian

| Komponen | Bobot | Yang diperiksa |
|---|---:|---|
| Observasi awal | 20% | Screenshot hasil sendiri: Compose, smoke, DNS/HTTP, challenge dan port awal; penjelasan status tepat. |
| Jaringan dan TLS | 30% | Hanya web terpublikasi; API/DB sehat; HTTPS tervalidasi; tidak ada jalur web langsung ke DB. |
| Healthcheck dan uji ulang | 25% | Lima fungsi bekerja, minimal 10 lolos, smoke dan challenge akhir lulus. |
| Penjelasan konsep | 15% | Enam jawaban modul menjelaskan DNS, TCP, proxy, HTTP, segmentasi, dan trust sertifikat. |
| Pengumpulan | 10% | `student.json`, laporan, screenshot pribadi, commit/push, dan Actions dapat diperiksa; tanpa kunci privat. |

Nilai didasarkan pada hasil, bukan pilihan Codespaces atau Docker lokal. Jika kuota Codespaces terbatas, terima jalur lokal dengan bukti setara. Screenshot modul yang disalin bukan bukti praktik.

## Masalah umum

| Gejala | Pemeriksaan dan tindakan |
|---|---|
| Compose tidak tersambung | Periksa Docker Engine/Codespaces selesai start, lalu `docker info`. Di Windows gunakan Git Bash/WSL yang terhubung ke Engine. |
| `bind: address already in use` | Hentikan service lokal yang memakai 8080, 3000, atau 5432; ulangi Compose. |
| API/DB belum healthy | `docker compose ps -a` dan `docker compose logs api db`; setelah perubahan jaringan pakai `--force-recreate`. |
| nginx gagal setelah `https.conf` dibuat | Pastikan sertifikat dibuat dahulu; baca `docker compose logs web`. |
| Browser memperingatkan HTTPS | Sertifikat self-signed belum dipercaya browser; verifikasi lab dengan `curl --cacert` dari toolbox. |
| Alat jaringan tidak ada di host | Jalankan `dig`, `nmap`, dan `openssl` dari toolbox. |
| Actions merah | Buka nama job: `student` perlu identitas, `challenge` merah pada starter; jika `stack` merah, baca log build dan smoke. |

## Pengumpulan dan penutupan

Mahasiswa menyalin `hasil/TEMPLATE_LAPORAN.md` menjadi `hasil/lab03.md`, menyimpan screenshot **milik sendiri** di `hasil/bukti/lab03/`, mengisi `student.json` tanpa NIM, memeriksa `git diff --cached`, lalu commit/push. Minta tautan repo pribadi, commit akhir, dan run Actions. Konfigurasi serta laporan boleh masuk Git; `web/certs/lab.key`, `.env`, token, password nyata, dan screenshot kredensial tidak boleh masuk. Tutup dengan `docker compose down`; `down -v` hanya untuk reset data yang memang diinginkan.
