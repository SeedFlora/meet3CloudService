# meet3CloudService — Lab 03 Networking & Web Services

Praktikum COMP6991031, sesi 3. Repo kelas [SeedFlora/meet3CloudService](https://github.com/SeedFlora/meet3CloudService) disiapkan untuk **GitHub Codespaces** atau Docker lokal. Empat service Docker Compose menyediakan target latihan: nginx (`web`), API Node.js (`api`), PostgreSQL (`db`), dan `toolbox` berisi `dig`, `nslookup`, `ping`, `traceroute`, `curl`, `wget`, `nmap`, `nc`, serta `openssl`.

**Mulai dari [modul mahasiswa bergambar](MODUL_MAHASISWA.md).** Setiap langkah bernomor mempunyai bukti visual beserta command, tujuan, cara kerja, dan hasil yang perlu dibaca. Foto Codespaces/browser/Docker adalah screenshot langsung; kartu terminal adalah keluaran perintah aktual yang ditata ulang. Gambar contoh bukan pengganti bukti praktik Anda sendiri.

Untuk dosen tersedia [panduan kelas, rubrik, dan langkah rinci challenge A-F](PANDUAN_DOSEN_TEMPLATE.md). Versi PDF untuk dibaca atau dicetak: [modul mahasiswa](output/pdf/MODUL_MAHASISWA_LAB03.pdf), [panduan dosen](output/pdf/PANDUAN_DOSEN_LAB03.pdf), [panduan Git](output/pdf/PANDUAN_GIT_LAB03.pdf), dan **[kunci jawaban mahasiswa terpisah](output/pdf/KUNCI_JAWABAN_MAHASISWA_LAB03.pdf)**. [Sumber Markdown kunci jawaban](KUNCI_JAWABAN_MAHASISWA_LAB03.md) memudahkan penyalinan kode. [Slide Lab 03 bergambar](slides/LAB03_Networking_Revisi_Bukti_Live.pptx) berisi command, hasil, dan penjelasan untuk presentasi kelas.

Verifikasi 1 Oktober 2026: Codespaces pada commit `5825663` berhasil menjalankan empat service, smoke **12 PASS/0 FAIL**, dan form web menyimpan catatan dengan **201 Created**. Solusi yang diuji lokal menghasilkan healthcheck **16 PASS/0 FAIL** dan challenge **15 PASS/0 FAIL**. Kunci jawaban tersedia terpisah; challenge pada starter memang merah sebelum dikerjakan.

## Jalur kelas: GitHub Codespaces

1. Buka [repo kelas](https://github.com/SeedFlora/meet3CloudService), pilih **Use this template → Create a new repository**, lalu isi nama repo pribadi. Visibilitas repo mengikuti arahan dosen.
2. Di repo pribadi, pilih **Code → Codespaces → Create codespace on main**. Tunggu `postCreateCommand` menyiapkan alat dan image. Bila persiapan image terputus, jalankan langkah berikut di terminal Codespace.
3. Dari root repo Codespace:

   ```bash
   docker compose config -q
   docker compose up -d --build --wait
   docker compose ps
   bash tests/smoke.sh
   ```

4. Di panel **Ports**, buka port **8080** untuk melihat web. Jika port terdeteksi dan diminta visibilitas, biarkan **Private** untuk praktikum. Lanjutkan [langkah DNS hingga TLS](MODUL_MAHASISWA.md#2-periksa-dns-dan-konektivitas-dari-toolbox).

File `.devcontainer/devcontainer.json` dan `.github/workflows/ci.yml` sudah berada di **root repo**, sehingga Codespaces dan Actions dapat menemukannya.

## Jalur laptop lokal

Pasang Docker Desktop/Engine dan Compose plugin. Clone repo pribadi Anda, lalu jalankan perintah yang sama dari root repo. Di Windows, perintah `bash tests/...` dijalankan dari Git Bash atau WSL yang tersambung ke Docker Engine. Web awal tersedia di <http://localhost:8080>. Jika port 8080, 3000, atau 5432 sedang dipakai, hentikan service lain lebih dahulu.

## Alur dan hasil belajar

Browser → `web:80` → `api:3000` → `db:5432`. DNS internal Docker menyelesaikan nama service; jaringan `edge`, `app`, dan `data` memisahkan tier. Konfigurasi awal **sengaja** menerbitkan port API dan database ke host. Mahasiswa mengamati DNS, konektivitas, HTTP, port, dan sertifikat, lalu memperbaiki exposure dan mengaktifkan HTTPS self-signed.

Pekerjaan kode yang diperlukan adalah mengubah `compose.yaml` dan `web/nginx/https.conf`, serta melengkapi fungsi TODO di `scripts/healthcheck.sh`. Tidak perlu menulis aplikasi frontend/backend baru untuk sesi ini.

## Pengumpulan

Isi `student.json` tanpa NIM, salin [templat laporan](hasil/TEMPLATE_LAPORAN.md) ke `hasil/lab03.md`, dan simpan screenshot hasil sendiri dalam `hasil/bukti/lab03/`. Ikuti [panduan Git](PANDUAN_GIT.md) untuk commit dan push repo pribadi. Job Actions `student` akan merah sebelum `student.json` diisi; job `challenge` sengaja merah pada starter hingga tantangan selesai.

Jalankan pemindaian hanya pada service lab sendiri. Jangan commit private key, token, password nyata, atau data pribadi. Password `labpass` di `compose.yaml` adalah data latihan yang memang sengaja dibagikan, bukan kredensial layanan pribadi.

## Berhenti

```bash
docker compose down
```

Perintah tersebut mempertahankan volume database. `docker compose down -v` menghapus data latihan jika Anda memang ingin mengulang dari awal.

Lisensi kode: [MIT](LICENSE).
