# Laporan Lab 03 — Networking & Web Services

- Nama/kelompok:
- Kelas:
- Tanggal:
- Lingkungan: Codespaces / lokal, versi Docker Compose:
- URL repo dan commit:

## Topologi dan alur request

Gambarkan browser → nginx → API → database. Tulis nama service, jaringan, dan port pada setiap perpindahan.

## Hasil praktik

| Checkpoint | Perintah | Hasil yang diharapkan | Hasil nyata dan bukti |
|---|---|---|---|
| 1. Stack awal | `docker compose ps`, `bash tests/smoke.sh` | Web/API/DB sehat | |
| 2. DNS dan konektivitas | `dig`, `nslookup`, `ping`, `traceroute` | Nama service menjadi IP internal | |
| 3. HTTP | `curl -i`, `wget` | Status 200, 201, 404 | |
| 4. Port awal | `nmap`, `nc`, `tests/challenge.sh` | Temuan port host API/DB | |
| 5. TLS dan perbaikan | `openssl`, `curl --cacert`, `docker compose ps` | HTTPS valid untuk sertifikat lab; hanya web terpublikasi | |

## Screenshot hasil sendiri

Simpan dalam `hasil/bukti/lab03/`, lalu tautkan berkas hasil Anda dari laporan, misalnya berkas `bukti/lab03/compose-awal.png` setelah screenshot tersebut dibuat. Gambar contoh di modul bukan bukti hasil Anda. Samarkan token, data pribadi, dan kredensial sebelum commit.

## Jawaban pertanyaan modul

1. Jalur request dan jaringan:
2. Arti `web`, `api`, dan `localhost` pada host vs toolbox:
3. Perbedaan akses API langsung dan melalui nginx:
4. Arti status HTTP 200, 201, 404, 400:
5. Mengapa web tidak perlu jaringan langsung ke DB dan apa akibat menghapus `ports:` DB:
6. Mengapa `--cacert` menerima sertifikat self-signed lab:

## Masalah dan penyelesaian

Catat error yang benar-benar muncul, langkah perbaikan, serta batasan jaringan Codespaces/lokal jika ada. Jangan menyalin private key atau password nyata.
