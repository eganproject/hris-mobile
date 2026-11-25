import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Token dan ID perangkat disimpan di secure storage (Keychain / Keystore).
/// ID perangkat dibuat sekali saat aplikasi pertama dipasang; inilah yang
/// diikat ke akun karyawan (satu HP per karyawan).
class SessionStorage {
  SessionStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  String? _deviceIdCache;

  static const _tokenKey = 'auth_token';
  static const _deviceKey = 'device_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<String> deviceId() async {
    if (_deviceIdCache != null) return _deviceIdCache!;
    var id = await _storage.read(key: _deviceKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _storage.write(key: _deviceKey, value: id);
    }
    return _deviceIdCache = id;
  }
}

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());
