# meet3CloudService — Lab 03 Networking & Web Services

<!-- lecture-materials:start -->

## Materi teori sebelum praktikum

- [Pertemuan 03: Networking & Web Services](slides/Teori_Pertemuan_03.pptx)

Slide menghubungkan konsep, kasus kerja, bacaan/video resmi, dan langkah lab.

<!-- lecture-materials:end -->

**Kebijakan kelas:** Lab ini latihan formatif, tanpa tugas, nilai, atau penyerahan terpisah. Satu proyek besar dikerjakan oleh kelompok **3 orang**, dengan presentasi checkpoint minggu 7 (UTS) dan hasil akhir minggu 14 (UAS). Simpan hasil lab hanya bila berguna sebagai referensi atau bukti proses proyek. Baca [brief proyek kelompok](PROYEK_KELOMPOK.md). Bobot resmi tetap mengikuti RPS/LMS.

Praktikum COMP6991031, sesi 3. Repo kelas [SeedFlora/meet3CloudService](https://github.com/SeedFlora/meet3CloudService) disiapkan untuk **GitHub Codespaces** atau Docker lokal. Empat service Docker Compose menyediakan target latihan: nginx (`web`), API Node.js (`api`), PostgreSQL (`db`), dan `toolbox` berisi `dig`, `nslookup`, `ping`, `traceroute`, `curl`, `wget`, `nmap`, `nc`, serta `openssl`.

**Mulai dari [modul mahasiswa bergambar](MODUL_MAHASISWA.md).** Setiap langkah bernomor mempunyai bukti visual beserta command, tujuan, cara kerja, dan hasil yang perlu dibaca. Foto Codespaces/browser/Docker adalah screenshot langsung; kartu terminal adalah keluaran perintah aktual yang ditata ulang. Gambar contoh bukan pengganti bukti praktik Anda sendiri.

Versi PDF untuk dibaca atau dicetak: [modul mahasiswa](output/pdf/MODUL_MAHASISWA_LAB03.pdf), dan **[kunci jawaban mahasiswa terpisah](output/pdf/KUNCI_JAWABAN_MAHASISWA_LAB03.pdf)**. [Sumber Markdown kunci jawaban](KUNCI_JAWABAN_MAHASISWA_LAB03.md) memudahkan penyalinan kode. [Slide Lab 03 bergambar](slides/LAB03_Networking_Revisi_Bukti_Live.pptx) berisi command, hasil, dan penjelasan untuk presentasi kelas.

Verifikasi 1 Oktober 2026: Codespaces pada commit `5825663` berhasil menjalankan empat service, smoke **12 PASS/0 FAIL**, dan form web menyimpan catatan dengan **201 Created**. Solusi yang diuji lokal menghasilkan healthcheck **16 PASS/0 FAIL** dan challenge **15 PASS/0 FAIL**. Kunci jawaban tersedia terpisah; challenge pada starter memang merah sebelum dikerjakan.

## Jalur lokal Windows

## 0. Clone ke laptop

Buka Docker Desktop hingga **Engine running**, kemudian buka **Git Bash**. Jalankan blok ini sekali untuk membuat salinan baru di folder pengguna:

```bash
cd ~
git clone https://github.com/SeedFlora/meet3CloudService.git meet3CloudService-local
cd meet3CloudService-local
pwd
ls compose.yaml tests/smoke.sh
```

Hasil: terminal berada di `meet3CloudService-local` dan kedua file ditemukan. Buka folder ini di VS Code. Inilah root repo untuk seluruh perintah host berikut. Folder clone yang sudah tersedia boleh dibuka langsung, lalu periksa `pwd` dan dua file tersebut. Tidak perlu membuat Codespace atau repo pribadi untuk praktik lokal.



Setelah clone selesai, terminal tetap di root repo. Jalankan:

```bash
docker compose config -q
docker compose up -d --build --wait
docker compose ps
bash tests/smoke.sh
```

Buka <http://localhost:8080> untuk melihat web. Lanjutkan [langkah DNS hingga TLS](MODUL_MAHASISWA.md#2-periksa-dns-dan-konektivitas-dari-toolbox). Jalankan perintah satu per satu dan perhatikan kapan terminal berada di host atau di dalam toolbox.

File `.devcontainer/devcontainer.json` dan `.github/workflows/ci.yml` sudah berada di **root repo**, sehingga Codespaces dan Actions dapat menemukannya.

## Persiapan dan alternatif Codespaces

Docker Desktop/Engine dan Compose plugin harus tersedia. Host port awal adalah 8080, 3000, dan 5432. Hentikan server Lab 01 dengan Ctrl+C sebelum menjalankan stack ini.

Codespaces dapat dipakai sebagai alternatif melalui **Code → Codespaces → Create codespace on main**. Jalankan blok Compose yang sama dan buka web dari tab **Ports 8080**. Pada laptop, seluruh praktik berjalan lokal. Di Git Bash, awalan `MSYS_NO_PATHCONV=1` pada perintah TLS menjaga path `/lab/...` tetap menjadi path Linux di container. Awalan itu juga aman di Bash Linux.

## Alur dan hasil belajar

Browser → `web:80` → `api:3000` → `db:5432`. DNS internal Docker menyelesaikan nama service; jaringan `edge`, `app`, dan `data` memisahkan tier. Konfigurasi awal **sengaja** menerbitkan port API dan database ke host. Mahasiswa mengamati DNS, konektivitas, HTTP, port, dan sertifikat, lalu memperbaiki exposure dan mengaktifkan HTTPS self-signed.

Pekerjaan kode yang diperlukan adalah mengubah `compose.yaml` dan `web/nginx/https.conf`, serta melengkapi fungsi TODO di `scripts/healthcheck.sh`. Tidak perlu menulis aplikasi frontend/backend baru untuk sesi ini.

## Catatan latihan

Isi `student.json` tanpa NIM untuk mencoba alur CI. Bila ingin menyimpan proses sebagai referensi proyek, salin [templat catatan](hasil/TEMPLATE_LAPORAN.md) ke `hasil/lab03.md` dan simpan screenshot hasil sendiri dalam `hasil/bukti/lab03/`. [Panduan Git](PANDUAN_GIT.md) menjelaskan commit dan push opsional ke repo pribadi. Job Actions `student` akan merah sebelum `student.json` diisi; job `challenge` sengaja merah pada starter hingga tantangan selesai.

Jalankan pemindaian hanya pada service lab sendiri. Jangan commit private key, token, password nyata, atau data pribadi. Password `labpass` di `compose.yaml` adalah data latihan yang memang sengaja dibagikan, bukan kredensial layanan pribadi.

## Berhenti

```bash
docker compose down
```

Perintah tersebut mempertahankan volume database. `docker compose down -v` menghapus data latihan jika Anda memang ingin mengulang dari awal.

Lisensi kode: [MIT](LICENSE).
