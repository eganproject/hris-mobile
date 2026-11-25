# HRIS COK — aplikasi HP

Aplikasi Flutter (Android 7+ dan iOS 15+) untuk HRIS Cahaya Optima Karya.
Backend: repo `eganproject/hris` (Laravel), API di `/api/mobile/v1`.

## Tahap 1 — absensi
- Login dengan akun HRIS web (email atau NIK). Satu akun = satu HP; HP
  pertama aktif otomatis, ganti HP disetujui HR (menu web *Absen Aplikasi HP*).
- Persetujuan penyimpanan selfie & lokasi (UU PDP) sekali per HP.
- Absen masuk/pulang: selfie kamera depan (tekan tombol, tanpa cek kedip),
  lokasi GPS dibandingkan radius Lokasi Kerja; WFH/dinas luar tanpa radius.
- Lokasi palsu (fake GPS) dan HP root/jailbreak ditolak server; percobaannya tercatat.
- Antrean offline: absen tanpa sinyal disimpan dengan ID unik dan jam saat
  tombol ditekan, dikirim ulang otomatis (tiap 30 detik / saat online) sampai
  server menjawab.
- Setelah absen masuk, tombol berganti Absen Pulang sampai pulang (batas sesi
  diatur di Pengaturan web, default 23 jam 50 menit).
- Riwayat bulanan dan koreksi absensi.

## Tahap 2
Pengajuan, jadwal, notifikasi, fitur atasan, Kabar, struktur organisasi:
fitur di `lib/features/<fitur>/`, rute di `lib/features/tahap2_routes.dart`.

## Struktur
```
lib/core/     api client (apiClientProvider, apiErrorMessage), auth, router, tema, widget umum
lib/features/ auth, beranda, absen, riwayat, koreksi, kabar, pengajuan, profil
```

## Menjalankan
```
flutter pub get
flutter run --dart-define=API_BASE_URL=https://alamat-hris-anda
flutter build apk --release --dart-define=API_BASE_URL=https://alamat-hris-anda
```
Tanpa `API_BASE_URL`, aplikasi memakai `https://cok-hris.com`. Untuk Laravel lokal dari emulator Android pakai `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.

Catatan iOS: membaca nama/BSSID Wi-Fi butuh capability *Access WiFi Information*
di Xcode; tanpa itu absen tetap jalan, hanya bukti Wi-Fi yang kosong.
