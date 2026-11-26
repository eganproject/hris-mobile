# HRIS COK — aplikasi HP

Aplikasi Flutter (Android 7+ dan iOS 15+) untuk HRIS Cahaya Optima Karya.
Backend: repo `eganproject/hris` (Laravel), API di `/api/mobile/v1`.

## Fungsi
Aplikasi layanan mandiri karyawan. Absen masuk/pulang TIDAK lewat HP:
kantor memakai tablet pengenalan wajah, gudang memakai mesin absen.
- Login dengan akun HRIS web (email atau NIK), boleh dari HP mana saja.
- Beranda: jadwal dan jam masuk/pulang hari ini (hanya dibaca).
- Riwayat bulanan dan koreksi absensi.
- Pengajuan cuti/izin/sakit, lembur, tukar jadwal; jadwal saya.
- Pengumuman HR, struktur organisasi, notifikasi, profil + foto.
- Atasan: persetujuan, tim hari ini, atur jadwal tim.
Rute fitur di `lib/features/tahap2_routes.dart`.

## Struktur
```
lib/core/     api client (apiClientProvider, apiErrorMessage), auth, router, tema, widget umum
lib/features/ auth, beranda, absen (status & riwayat), riwayat, koreksi, pengajuan, pengumuman, profil, tim
```

## Menjalankan
```
flutter pub get
flutter run --dart-define=API_BASE_URL=https://alamat-hris-anda
flutter build apk --release --dart-define=API_BASE_URL=https://alamat-hris-anda
```
Tanpa `API_BASE_URL`, aplikasi memakai `http://10.0.2.2:8000` (Laravel lokal dari emulator Android).
