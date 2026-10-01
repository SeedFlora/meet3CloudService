# Menyiapkan repo template kelas Lab 03

Folder ini sudah berupa **root repo Lab 03**: `compose.yaml`, `.devcontainer/`, `.github/workflows/`, `MODUL_MAHASISWA.md`, `screenshots/`, dan `hasil/` sejajar. Tidak perlu memindahkan folder `starter` lagi.

1. Repo tujuan kelas adalah [SeedFlora/meet3CloudService](https://github.com/SeedFlora/meet3CloudService). Jalankan perintah dari **root folder ini**, tempat `compose.yaml` berada. Untuk pembaruan berikutnya, periksa `git remote -v` dan `git status` dahulu.
2. Periksa file yang akan dipush, lalu hubungkan repo tersebut:

   ```bash
   git init
   git branch -M main
   git add -A
   git diff --cached --name-only
   git diff --cached --check
   git commit -m "first commit"
   git remote add origin https://github.com/SeedFlora/meet3CloudService.git
   git push -u origin main
   ```

   Periksa staged diff sebelum commit; jangan masukkan solusi, sertifikat privat, atau file kredensial. Jika repo ini sudah pernah diinisialisasi, periksa `git remote -v` dan `git status` sebelum mengulang perintah.
3. Di GitHub, aktifkan **Settings → General → Template repository**. Bagikan URL template yang baru dibuat kepada mahasiswa. Mahasiswa memilih **Use this template**, membuat repo sendiri, lalu membuka Codespaces dari repo tersebut.
4. Untuk demo, jalankan `docker compose config -q`, `docker compose up -d --build --wait`, `docker compose ps`, dan `bash tests/smoke.sh`. Tampilkan web melalui port 8080 pada panel Ports; lanjutkan checkpoint di [modul mahasiswa](MODUL_MAHASISWA.md). Jalankan nmap hanya terhadap service lab ini.

Konfigurasi awal sengaja membuat job Actions `challenge` merah. Job `student` juga merah sampai pemilik repo mengisi `student.json`. Jelaskan dua status ini sebelum mahasiswa menafsirkan run Actions sebagai error platform.

Codespaces memerlukan akun GitHub dan kuota/akses organisasi yang sesuai. Jalur lokal dengan Docker tetap tersedia. Repo template dan Codespace belum dibuat otomatis oleh paket lokal ini; push ke GitHub memerlukan akun, URL repo, dan autentikasi dosen.
