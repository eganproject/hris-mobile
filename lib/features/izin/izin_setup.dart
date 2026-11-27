import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

/// Izin yang diminta saat aplikasi pertama kali dibuka sesudah login
/// (Profil > Izin aplikasi membuka alur yang sama).
enum IzinStep { notifikasi, baterai, otomatis, kamera, pembaruan }

const _helpChannel = MethodChannel('hris/notif-help');

/// Keadaan izin di HP ini. `null` = HP tidak bisa memastikan (mulai otomatis).
class IzinStatus {
  const IzinStatus({
    required this.notifikasi,
    required this.baterai,
    required this.kamera,
    required this.pembaruan,
    required this.hasAutostart,
  });

  final bool notifikasi;
  final bool baterai;
  final bool kamera;
  final bool pembaruan;

  /// HP dengan halaman "mulai otomatis" (Xiaomi, Oppo, Vivo, Realme, Huawei).
  final bool hasAutostart;

  bool? granted(IzinStep step) => switch (step) {
        IzinStep.notifikasi => notifikasi,
        IzinStep.baterai => baterai,
        IzinStep.otomatis => null,
        IzinStep.kamera => kamera,
        IzinStep.pembaruan => pembaruan,
      };

  /// Langkah yang ditampilkan di HP ini.
  List<IzinStep> get steps => [
        IzinStep.notifikasi,
        if (Platform.isAndroid) IzinStep.baterai,
        if (hasAutostart) IzinStep.otomatis,
        IzinStep.kamera,
        if (Platform.isAndroid) IzinStep.pembaruan,
      ];

  static Future<IzinStatus> read() async {
    // Di luar Android/iOS (mis. tes) tidak ada izin yang bisa dibaca.
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const IzinStatus(notifikasi: false, baterai: true, kamera: false, pembaruan: true, hasAutostart: false);
    }
    Future<bool> ok(Permission p) async {
      try {
        return await p.isGranted;
      } catch (_) {
        return true;
      }
    }

    var hasAutostart = false;
    if (Platform.isAndroid) {
      try {
        final s = await _helpChannel.invokeMapMethod<dynamic, dynamic>('status');
        hasAutostart = s?['hasAutostart'] as bool? ?? false;
      } catch (_) {}
    }

    return IzinStatus(
      notifikasi: await ok(Permission.notification),
      baterai: !Platform.isAndroid || await ok(Permission.ignoreBatteryOptimizations),
      kamera: await ok(Permission.camera) && await ok(Permission.locationWhenInUse),
      pembaruan: !Platform.isAndroid || await ok(Permission.requestInstallPackages),
      hasAutostart: hasAutostart,
    );
  }
}

/// Meminta izin satu langkah. Mengembalikan setelah dialog Android ditutup,
/// atau segera setelah halaman setelan dibuka (yang dicek lagi saat kembali).
Future<void> requestIzin(IzinStep step) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    switch (step) {
      case IzinStep.notifikasi:
        final s = await Permission.notification.request();
        if (s.isPermanentlyDenied) await _helpChannel.invokeMethod<bool>('openNotificationSettings');
      case IzinStep.baterai:
        final s = await Permission.ignoreBatteryOptimizations.request();
        if (!s.isGranted) await _helpChannel.invokeMethod<bool>('requestBattery');
      case IzinStep.otomatis:
        await _helpChannel.invokeMethod<bool>('openAutostart');
      case IzinStep.kamera:
        await Permission.locationWhenInUse.request();
        await Permission.camera.request();
      case IzinStep.pembaruan:
        await Permission.requestInstallPackages.request();
    }
  } catch (_) {
    // Izin tidak tersedia di HP ini: lewati saja.
  }
}

/// Sudahkah alur izin ditampilkan di HP ini? Disimpan per HP, bukan per akun.
/// `null` selama dibaca; gagal membaca dianggap sudah (jangan menghalangi).
class IzinSetupDone extends Notifier<bool?> {
  static const _key = 'izin_setup_v1';
  final _storage = const FlutterSecureStorage();

  @override
  bool? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final v = await _storage.read(key: _key);
      state = v == '1';
    } catch (_) {
      state = true;
    }
  }

  Future<void> markDone() async {
    state = true;
    try {
      await _storage.write(key: _key, value: '1');
    } catch (_) {}
  }
}

final izinSetupDoneProvider = NotifierProvider<IzinSetupDone, bool?>(IzinSetupDone.new);
