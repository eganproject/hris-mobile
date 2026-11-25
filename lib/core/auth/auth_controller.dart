import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'device_identity.dart';
import 'models.dart';
import 'session_storage.dart';

/// Keadaan login aplikasi.
sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.message});

  /// Alasan keluar (mis. HP dicabut HR), ditampilkan di layar login.
  final String? message;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);
  final AppUser user;
}

/// Login ditolak karena HP ini menunggu persetujuan HR / ditolak.
class DevicePendingException implements Exception {
  DevicePendingException(this.message, this.code);
  final String message;
  final String code;
  @override
  String toString() => message;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Daftarkan penanganan 401: token dicabut → keluar.
    Future.microtask(_restore);
    return const AuthLoading();
  }

  SessionStorage get _storage => ref.read(sessionStorageProvider);
  Dio get _dio => ref.read(apiClientProvider);

  Future<void> _restore() async {
    final token = await _storage.readToken();
    if (token == null) {
      state = const AuthSignedOut();
      return;
    }
    try {
      final res = await _dio.get('/me');
      state = AuthSignedIn(AppUser.fromJson((res.data['data'] as Map).cast<String, dynamic>()));
    } catch (e) {
      final err = toApiException(e);
      if (err.isNetwork) {
        // Offline saat membuka aplikasi: tetap masuk dengan profil kosong tidak
        // mungkin, jadi coba lagi sebentar lagi tanpa membuang token.
        state = const AuthSignedOut(message: 'Tidak ada koneksi. Buka lagi aplikasinya saat online.');
        Future.delayed(const Duration(seconds: 5), _restore);
        return;
      }
      await _storage.clearToken();
      state = AuthSignedOut(message: err.statusCode == 401 ? err.message : null);
    }
  }

  Future<void> retry() => _restore();

  /// Masuk dengan email/NIK + kata sandi. Melempar [DevicePendingException]
  /// bila akun sudah terikat ke HP lain (menunggu HR).
  Future<void> login(String login, String password) async {
    final identity = await DeviceIdentity.load();
    final deviceId = await _storage.deviceId();
    try {
      final res = await _dio.post('/auth/login', data: {
        'login': login.trim(),
        'password': password,
        'device_id': deviceId,
        ...identity.toJson(),
      });
      final data = (res.data['data'] as Map).cast<String, dynamic>();
      await _storage.writeToken(data['token'] as String);
      state = AuthSignedIn(AppUser.fromJson(
        (data['user'] as Map).cast<String, dynamic>(),
        device: (data['device'] as Map).cast<String, dynamic>(),
      ));
    } catch (e) {
      final err = toApiException(e);
      if (err.statusCode == 403 && (err.code == 'device_pending' || err.code == 'device_rejected')) {
        throw DevicePendingException(err.message, err.code!);
      }
      throw err;
    }
  }

  /// Persetujuan penyimpanan selfie & lokasi (layar "Daftarkan HP ini").
  Future<void> giveConsent() async {
    final current = state;
    if (current is! AuthSignedIn) return;
    final res = await _dio.post('/auth/consent', data: {'agree': true});
    final device = ((res.data['data'] as Map)['device'] as Map).cast<String, dynamic>();
    state = AuthSignedIn(current.user.copyWith(device: DeviceInfoDto.fromJson(device)));
  }

  Future<void> refreshProfile() async {
    final res = await _dio.get('/me');
    state = AuthSignedIn(AppUser.fromJson((res.data['data'] as Map).cast<String, dynamic>()));
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Tetap keluar walau server tidak terjangkau.
    }
    await _storage.clearToken();
    state = const AuthSignedOut();
  }

  /// Dipanggil interceptor saat server menjawab 401.
  Future<void> forceSignOut(String message) async {
    await _storage.clearToken();
    state = AuthSignedOut(message: message.isEmpty ? 'Sesi berakhir. Silakan masuk lagi.' : message);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Pengguna yang sedang masuk (null bila belum).
final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSignedIn ? state.user : null;
});
