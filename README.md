# HRIS COK — aplikasi HP

Aplikasi Flutter (Android 7+ dan iOS 15+) untuk HRIS Cahaya Optima Karya.
Backend: repo `eganproject/hris` (Laravel), API di `/api/mobile/v1`.

## Fungsi
Aplikasi layanan mandiri karyawan. Absen masuk/pulang TIDAK lewat HP:
kantor memakai tablet pengenalan wajah, gudang memakai mesin absen.
- Login dengan akun HRIS web (email atau NIK), boleh dari HP mana saja.
- Menu bawah karyawan: Beranda · Kehadiran · Pengajuan · Info · Profil.
  Atasan (punya bawahan): Info diganti Tim, dengan badge persetujuan.
- Beranda: jam masuk/pulang hari ini (hanya dibaca), jalan pintas pengajuan,
  sisa cuti, jadwal besok, pengumuman HR terbaru.
- Kehadiran: riwayat bulanan (+ koreksi) dan jadwal saya per minggu.
- Pengajuan cuti/izin/sakit, lembur, tukar jadwal, koreksi.
- Info: pengumuman HR dan rekan kerja (cari, status aktif).
- Tim (atasan): tim hari ini, persetujuan, atur jadwal tim, struktur.
- Profil: data diri, struktur organisasi, notifikasi, keluar.
Rute fitur di `lib/features/tahap2_routes.dart`.

Tampilan (desain ulang 26 Nov 2026) selaras dengan HRIS web dan tablet:
font Inter, navy `#16255A`, aksen kuning `#F9AE05`, latar abu bertitik.
Token warna di `lib/core/theme/app_colors.dart`, widget umum di
`lib/core/widgets/ui.dart` (DotScaffold, NavyHeroCard, SegmentedTabs, dsb.).

## Struktur
```
lib/core/     api client (apiClientProvider, apiErrorMessage), auth, router, tema, widget umum
lib/features/ auth, beranda, absen (status & riwayat), kehadiran, jadwal, koreksi, pengajuan, info, pengumuman, profil, tim
```

## Menjalankan
```
flutter pub get
flutter run --dart-define=API_BASE_URL=https://alamat-hris-anda
flutter build apk --release --dart-define=API_BASE_URL=https://alamat-hris-anda
```
Tanpa `API_BASE_URL`, aplikasi memakai `http://10.0.2.2:8000` (Laravel lokal dari emulator Android).

## Tes
```
flutter analyze
flutter test
```
`test/screens_test.dart` menampilkan setiap tab (karyawan & atasan) dengan data
API palsu dan gagal bila ada galat atau tampilan meluber. Tangkapan layar:
`SHOTS_DIR=/folder flutter test test/screens_test.dart --update-goldens`.
