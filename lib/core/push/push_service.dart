import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> register([String? token]) async {
    if (ref.read(currentUserProvider) == null) return;
    try {
      await messaging
          .requestPermission(); // Android 13+: izin tampilkan notifikasi.
      // Token FCM klasik: pasti diterima API HTTP v1 di server. API FID yang
      // baru (register/onRegistered) belum dipakai sampai servernya diuji.
      // ignore: deprecated_member_use
      final value = token ?? await messaging.getToken();
      if (value == null) return;
      await ref
          .read(apiClientProvider)
          .post('/push-token', data: {'token': value});
    } catch (e) {
      debugPrint('Gagal mendaftarkan token notifikasi: $e');
    }
  }

  void open(RemoteMessage message) {
    final route = message.data['category'] == 'attendance'
        ? '/kehadiran'
        : '/notifikasi';
    ref.read(routerProvider).go(route);
  }

  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    if (next is AuthSignedIn && prev is! AuthSignedIn) register();
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
