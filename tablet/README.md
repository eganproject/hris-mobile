# Absensi Tablet (wajah)

Aplikasi Android untuk tablet di kantor: karyawan cukup menghadapkan wajah ke
kamera, absen masuk/pulang tercatat otomatis di HRIS (tabel absensi yang sama
dengan mesin X100-C dan aplikasi HP).

## Memasang tablet

1. Unduh APK: GitHub → Actions → **Build APK Tablet** → run terbaru → Artifacts
   → `absensi-tablet-apk`. Pasang di tablet (izinkan "sumber tidak dikenal").
2. Di web HRIS: **Absensi → Tablet Absensi Wajah → Daftarkan tablet** (pilih
   Lokasi Kerja). Ketik kode pasangan yang muncul di tablet.
3. Di web, klik **Atur PIN HR** untuk tablet itu (6 angka).
4. Di tablet, ketuk ikon gembok → PIN HR → **Daftar wajah karyawan**. Karyawan
   berdiri di depan tablet, 3 foto (depan, kiri, kanan) diambil otomatis,
   centang persetujuan UU PDP, **Simpan wajah**.
5. Menu HR → **Kunci layar (sematkan aplikasi)** agar tablet tidak dipakai untuk
   aplikasi lain. Aktifkan dulu *Setelan → Keamanan → Sematkan aplikasi*.

## Cara kerja

- Deteksi wajah: Google ML Kit. Pengenalan: MobileFaceNet (InsightFace
  `w600k_mbf`, dikonversi ke TFLite). Cek wajah asli: MiniFASNetV2 + V1SE.
  Semua berjalan di dalam tablet; data wajah (pola angka) diunduh dari HRIS
  sehingga tetap jalan saat internet putus.
- Absen terjadi bila orang yang sama cocok 3 bingkai berturut-turut, skor ≥
  ambang (Normal 0,40) dan unggul ≥ 0,06 dari karyawan lain, wajah cukup terang,
  menghadap depan, dan berada pada jarak normal (kepala + bahu terlihat).
- Masuk/pulang ditentukan server: sesi terbuka (≤ 23j50m) = pulang. Pindai ulang
  < 1 menit diabaikan. Layar hasil tampil 4 detik dengan tombol **Bukan saya**
  sebelum absen dikirim.
- Offline: absen + foto bukti disimpan di tablet (UUID) dan dikirim otomatis.
- Cadangan **NIK + PIN** (PIN karyawan diatur HR di web) selalu difoto dan
  ditandai untuk HR. Cek wajah asli, tingkat kecocokan, dan NIK + PIN diatur di
  web (Pengaturan pengenalan wajah).

## Pengembangan

```
cd tablet
flutter pub get
flutter analyze && flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://cok-hris.com
```

API server: `/api/tablet/v1` (pair, sync, attendance, faces) di repo `hris`.
