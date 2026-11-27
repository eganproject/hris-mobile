import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifikasi/notifikasi_page.dart';
import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../router/app_router.dart';

/// Notifikasi dari server (Firebase Cloud Messaging), termasuk saat aplikasi
/// ditutup: Android sendiri yang menampilkannya di bilah notifikasi.
///
/// Firebase hanya aktif bila APK dibuat dengan google-services.json (secret
/// GOOGLE_SERVICES_JSON di GitHub). Tanpa itu aplikasi tetap jalan, hanya
/// tanpa notifikasi push.
class PushService {
  PushService._();

  static bool _enabled = false;

  /// Benar bila Firebase berhasil dinyalakan di [init].
  static bool get enabled => _enabled;

  /// Dipanggil sekali di main() sebelum runApp.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _enabled = true;
    } catch (e) {
      debugPrint('Push nonaktif: $e');
    }
  }
}

Future<String> appVersion() async {
  final p = await PackageInfo.fromPlatform();
  return '${p.version}+${p.buildNumber}';
}

/// Menyambungkan HP ini ke server: daftarkan token setelah login, perbarui saat
/// Firebase memberi token baru, dan buka layar yang tepat saat notifikasi diketuk.
/// Cukup dibaca sekali (lihat HrisApp).
final pushRegistrarProvider = Provider<void>((ref) {
  if (!PushService.enabled) return;

  final messaging = FirebaseMessaging.instance;
  final subs = <StreamSubscription<dynamic>>[];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });

  // Yang terakhir berhasil dikirim ke server, supaya membuka aplikasi
  // berulang kali tidak mengirim ulang hal yang sama.
  String? sentKey;
  DateTime? sentAt;

  Future<void> register([String? token]) async {
    if (ref.read(currentUserProvider) == null) return;
    try {
      // Izinnya diminta di alur izin (/izin); di sini cukup dibaca, supaya
      // HR tahu bila izinnya dimatikan.
      final settings = await messaging.getNotificationSettings();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      // Token FCM klasik: pasti diterima API HTTP v1 di server. API FID yang
      // baru (register/onRegistered) belum dipakai sampai servernya diuji.
      // ignore: deprecated_member_use
      final value = token ?? await messaging.getToken();
      if (value == null) return;

      final key = '$value|$allowed';
      final fresh =
          sentAt != null &&
          DateTime.now().difference(sentAt!) < const Duration(hours: 6);
      if (key == sentKey && fresh) return;

      final version = await appVersion();
      await ref
          .read(apiClientProvider)
          .post(
            '/push-token',
            data: {'token': value, 'allowed': allowed, 'app_version': version},
          );
      sentKey = key;
      sentAt = DateTime.now();
    } catch (e) {
      // Dicoba lagi saat aplikasi dibuka berikutnya.
      debugPrint('Gagal mendaftarkan token notifikasi: $e');
    }
  }

  // Token didaftarkan ulang setiap aplikasi dibuka lagi: token bisa berganti
  // diam-diam, kiriman sebelumnya bisa gagal karena sinyal, dan izin
  // notifikasi bisa dimatikan dari setelan HP.
  final lifecycle = AppLifecycleListener(onResume: register);
  ref.onDispose(lifecycle.dispose);

  void open(RemoteMessage message) {
    final route = message.data['category'] == 'attendance'
        ? '/kehadiran'
        : '/notifikasi';
    ref.read(routerProvider).go(route);
  }

  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    if (next is AuthSignedIn && prev is! AuthSignedIn) {
      sentKey = null; // akun baru di HP ini: wajib didaftarkan ulang
      register();
    }
  }, fireImmediately: true);

  subs
    // ignore: deprecated_member_use
    ..add(messaging.onTokenRefresh.listen(register))
    // Aplikasi sedang dibuka: Android tidak menampilkan notifikasinya, jadi
    // cukup segarkan angka di lonceng.
    ..add(
      FirebaseMessaging.onMessage.listen(
        (_) => ref.invalidate(unreadNotificationCountProvider),
      ),
    )
    ..add(FirebaseMessaging.onMessageOpenedApp.listen(open));

  // Aplikasi dibuka dari notifikasi saat sebelumnya tertutup penuh.
  messaging.getInitialMessage().then((m) {
    if (m != null) open(m);
  });
});
