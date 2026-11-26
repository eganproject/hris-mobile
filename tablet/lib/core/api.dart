import 'dart:io';

import 'package:dio/dio.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;

  /// Tidak tersambung / server tidak menjawab: simpan dan coba lagi nanti.
  bool get isNetwork => status == null;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

class TabletApi {
  TabletApi({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: '${baseUrl ?? apiBaseUrl}/api/tablet/v1/',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json', 'X-App-Version': appVersion},
        ));

  final Dio _dio;
  String? token;

  Options get _auth => Options(headers: {'Authorization': 'Bearer $token'});

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final res = e.response;
      if (res == null) throw ApiException('Tidak tersambung ke server HRIS.');
      final data = res.data;
      var message = 'Server menolak permintaan (${res.statusCode}).';
      String? code;
      if (data is Map) {
        code = data['code'] as String?;
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          message = first is List && first.isNotEmpty ? first.first.toString() : first.toString();
        } else if (data['message'] is String) {
          message = data['message'] as String;
        }
      }
      throw ApiException(message, status: res.statusCode, code: code);
    }
  }

  Future<String> pair(String code, {String? deviceModel}) => _call(() async {
        final res = await _dio.post('pair', data: {'code': code, 'device_model': deviceModel, 'app_version': appVersion});
        return res.data['data']['token'] as String;
      });

  /// Mengembalikan JSON mentah supaya bisa disimpan untuk dipakai saat offline.
  Future<Map<String, dynamic>> sync({int queue = 0}) => _call(() async {
        final res = await _dio.get('sync', queryParameters: {'queue': queue}, options: _auth);
        return (res.data['data'] as Map).cast<String, dynamic>();
      });

  Future<Map<String, dynamic>> sendAttendance(PendingRecord r) => _call(() async {
        final form = FormData.fromMap({
          'client_uuid': r.uuid,
          'employee_id': r.employeeId,
          'captured_at': r.capturedAt.toUtc().toIso8601String(),
          'method': r.method,
          'match_score': ?r.matchScore?.toStringAsFixed(4),
          'match_margin': ?r.matchMargin?.toStringAsFixed(4),
          'liveness_checked': r.livenessChecked ? '1' : '0',
          'liveness_score': ?r.livenessScore?.clamp(0, 1).toStringAsFixed(4),
          'not_me': r.notMe ? '1' : '0',
          'requested_type': ?r.requestedType,
          if (r.photoPath != null && File(r.photoPath!).existsSync())
            'photo': await MultipartFile.fromFile(r.photoPath!, filename: 'bukti.jpg'),
        });
        final res = await _dio.post('attendance', data: form, options: _auth);
        return (res.data['data'] as Map).cast<String, dynamic>();
      });

  Future<void> enrollFace({
    required String hrPin,
    required int employeeId,
    required String model,
    required List<String> embeddings,
    required List<int> photoJpeg,
  }) =>
      _call(() async {
        final form = FormData()
          ..fields.addAll([
            MapEntry('hr_pin', hrPin),
            MapEntry('employee_id', '$employeeId'),
            MapEntry('model', model),
            for (final e in embeddings) MapEntry('embeddings[]', e),
            const MapEntry('consent', '1'),
          ])
          ..files.add(MapEntry('photo', MultipartFile.fromBytes(photoJpeg, filename: 'wajah.jpg')));
        await _dio.post('faces', data: form, options: _auth);
      });
}
