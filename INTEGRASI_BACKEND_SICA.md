# Integrasi awal Flutter SiCA ke Cloud Run

## Yang ditambahkan
- `lib/services/ai_api_service.dart`: HTTP client dengan timeout dan validasi status/JSON.
- `lib/screens/backend_test_screen.dart`: halaman tes `/health` dan `POST /api/v1/analyze` memakai data dummy.
- Tombol ikon cloud di AppBar halaman ekspedisi untuk membuka tes backend.
- Versi dinaikkan menjadi `1.0.2+3`.

## Uji di komputer pengembang
1. Ekstrak ZIP dan buka folder `hidro-surveyor-main` sebagai proyek Flutter.
2. Jalankan `flutter pub get`.
3. Jalankan `flutter analyze`.
4. Jalankan aplikasi di HP dengan internet aktif.
5. Dari layar SiCA, tekan ikon cloud di kanan atas.
6. Tekan `Tes koneksi /health`; hasil yang diharapkan menampilkan status backend aktif.
7. Tekan `Tes endpoint analisis dengan data dummy`; hasil yang diharapkan mengandung `INSUFFICIENT_EVIDENCE` dan `vision-v0-mock`. Ini bukan bukti bahwa model AI sudah terpasang.

## Batasan keamanan dan fungsi
- Backend saat ini publik dan belum memiliki autentikasi; halaman ini hanya mengirim payload dummy. Jangan mengirim data survei nyata atau identitas penanggung jawab sebelum akses backend diamankan.
- Endpoint analisis menerima metadata, belum mengunggah file foto/video. `local_path` di HP tidak dapat dibaca server.
- Integrasi ini belum mengubah SQLite, status sinkronisasi, hasil survei, atau proses WorkManager. Data lokal tetap tidak tersentuh.
- Tidak mengganti signing keystore. Untuk APK rilis, gunakan keystore rilis SiCA yang sama dengan instalasi sebelumnya.
