import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:safe_device/safe_device.dart';

/// Hasil pengecekan HP + lokasi sebelum mengambil selfie.
class LocationSnapshot {
  LocationSnapshot({
    this.position,
    required this.isMocked,
    required this.isRooted,
    this.wifiSsid,
    this.wifiBssid,
    this.error,
  });

  final Position? position;
  final bool isMocked;
  final bool isRooted;
  final String? wifiSsid;
  final String? wifiBssid;

  /// Pesan bila lokasi tidak bisa dibaca (izin ditolak, GPS mati).
  final String? error;

  double? distanceTo(double? lat, double? lng) {
    if (position == null || lat == null || lng == null) return null;
    return Geolocator.distanceBetween(position!.latitude, position!.longitude, lat, lng);
  }
}

class DeviceChecks {
  /// Minta izin lokasi bila perlu. Mengembalikan pesan error atau null.
  static Future<String?> ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'GPS mati. Nyalakan lokasi di pengaturan HP.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Izin lokasi ditolak. Absen membutuhkan lokasi.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Izin lokasi diblokir. Buka pengaturan aplikasi untuk mengizinkan lokasi.';
    }
    return null;
  }

  static Future<bool> isRooted() async {
    try {
      return await SafeDevice.isJailBroken;
    } catch (_) {
      return false;
    }
  }

  static Future<LocationSnapshot> read() async {
    final rooted = await isRooted();
    final permissionError = await ensureLocationPermission();

    Position? position;
    String? error = permissionError;
    var mocked = false;

    if (permissionError == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 15),
          ),
        );
        mocked = position.isMocked;
      } catch (_) {
        try {
          position = await Geolocator.getLastKnownPosition();
          mocked = position?.isMocked ?? false;
        } catch (_) {}
        if (position == null) error = 'Lokasi belum terbaca. Coba di tempat terbuka.';
      }
    }

    if (Platform.isAndroid && !mocked) {
      try {
        mocked = await SafeDevice.isMockLocation;
      } catch (_) {}
    }

    String? ssid;
    String? bssid;
    try {
      final info = NetworkInfo();
      bssid = await info.getWifiBSSID();
      ssid = await info.getWifiName();
      if (bssid == '02:00:00:00:00:00') bssid = null; // nilai palsu bila izin kurang
      ssid = ssid?.replaceAll('"', '');
    } catch (_) {}

    return LocationSnapshot(
      position: position,
      isMocked: mocked,
      isRooted: rooted,
      wifiSsid: ssid,
      wifiBssid: bssid,
      error: error,
    );
  }
}
