# Git dan pengumpulan Lab 03

Repo ini adalah satu lab mandiri. Jalankan semua perintah dari root, tempat `compose.yaml` berada.

## Mahasiswa: buat repo dan Codespace

1. Buka URL template dari dosen. Pilih **Use this template → Create a new repository**. Buat repo milik sendiri; visibilitas sesuai arahan kelas.
2. Dari repo sendiri pilih **Code → Codespaces → Create codespace on main**. Di Codespace, folder kerja yang dibuka adalah root repo ini.
3. Isi `student.json` dengan nama, kelas, username GitHub. Jangan tulis NIM. Jalankan `bash tests/test_student.sh`.
4. Kerjakan [modul bergambar](MODUL_MAHASISWA.md), termasuk screenshot hasil sendiri di `hasil/bukti/lab03/` dan laporan `hasil/lab03.md`.

## Commit dan push

```bash
git status --short
git add -A
git diff --cached --name-only
git diff --cached --check
git diff --cached
git check-ignore -v web/certs/lab.key
git commit -m "lab03: hasil networking dan web services"
git push
```

Sebelum commit, periksa daftar file dan diff. Jangan ikutkan `web/certs/lab.key`, `.env`, token, password nyata, NIM, atau screenshot kredensial. File konfigurasi nginx, Compose, `healthcheck.sh`, laporan, dan bukti aman boleh dipush. Bila `git push` pertama meminta upstream, jalankan `git push -u origin main` pada branch `main`.

Di tab **Actions**, job `student` akan merah selama `student.json` masih contoh. Job `challenge` sengaja merah pada starter; hijau setelah konfigurasi dan healthcheck berhasil. Tautan repo/commit dan hasil Actions dapat diberikan melalui kanal pengumpulan kelas.

Jika dosen hanya menggunakan jalur lokal tanpa pengumpulan Git, praktik Docker tetap dapat dijalankan dari folder ini tanpa push.
