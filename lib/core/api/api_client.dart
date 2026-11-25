import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_storage.dart';
import '../config.dart';

/// Kesalahan dari API yang sudah diterjemahkan ke pesan untuk pengguna.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.errors, this.isNetwork = false});

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? errors;

  /// True bila server tidak terjangkau (tanpa sinyal / timeout).
  final bool isNetwork;

  @override
  String toString() => message;
}

/// Dipanggil ketika server menolak token (401): sesi di HP dibersihkan.
typedef UnauthorizedHandler = Future<void> Function(String? code, String message);

final unauthorizedHandlerProvider = Provider<UnauthorizedHandler?>((ref) => null);

/// Dio yang sudah ber-baseUrl /api/mobile/v1, membawa Bearer token dan
/// header X-Device-Id. Dipakai semua fitur (Tahap 1 dan Tahap 2).
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(sessionStorageProvider);

  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 60),
    headers: {'Accept': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.readToken();
      final deviceId = await storage.deviceId();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      options.headers['X-Device-Id'] = deviceId;
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401 && error.requestOptions.path != '/auth/login') {
        final data = error.response?.data;
        final code = data is Map ? data['code'] as String? : null;
        final message = data is Map ? (data['message'] as String? ?? '') : '';
        final onUnauthorized = ref.read(unauthorizedHandlerProvider);
        if (onUnauthorized != null) await onUnauthorized(code, message);
      }
      handler.next(error);
    },
  ));

  return dio;
});

/// Ubah error apa pun (DioException, ApiException, lainnya) menjadi
/// [ApiException] dengan pesan berbahasa Indonesia.
ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Tidak ada koneksi ke server. Periksa sinyal atau Wi-Fi.', isNetwork: true);
      default:
        break;
    }
    final response = error.response;
    if (response == null) {
      return ApiException('Tidak ada koneksi ke server. Periksa sinyal atau Wi-Fi.', isNetwork: true);
    }
    final data = response.data;
    if (data is Map) {
      final errors = data['errors'] is Map ? Map<String, dynamic>.from(data['errors'] as Map) : null;
      String? first;
      if (errors != null && errors.isNotEmpty) {
        final value = errors.values.first;
        first = value is List && value.isNotEmpty ? value.first.toString() : value.toString();
      }
      return ApiException(
        first ?? (data['message'] as String?) ?? 'Terjadi kesalahan (${response.statusCode}).',
        statusCode: response.statusCode,
        code: data['code'] as String?,
        errors: errors,
      );
    }
    if ((response.statusCode ?? 0) >= 500) {
      return ApiException('Server sedang bermasalah. Coba lagi sebentar lagi.', statusCode: response.statusCode);
    }
    return ApiException('Terjadi kesalahan (${response.statusCode}).', statusCode: response.statusCode);
  }
  return ApiException(error.toString());
}

/// Pesan error yang siap ditampilkan ke pengguna.
String apiErrorMessage(Object error) => toApiException(error).message;
