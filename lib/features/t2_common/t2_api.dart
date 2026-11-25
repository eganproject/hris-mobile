import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

/// Pembungkus tipis di atas Dio milik core (sudah ber-baseUrl /api/mobile/v1,
/// token Bearer, dan X-Device-Id). Semua respons API tahap 2 berbentuk
/// {data, meta?, message?}.
class T2Api {
  T2Api(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final res = await dio.get(_p(path), queryParameters: query);
    return _map(res.data);
  }

  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    final res = await dio.post(_p(path), data: data);
    return _map(res.data);
  }

  Future<Map<String, dynamic>> put(String path, {Object? data}) async {
    final res = await dio.put(_p(path), data: data);
    return _map(res.data);
  }

  Future<Map<String, dynamic>> patch(String path, {Object? data}) async {
    final res = await dio.patch(_p(path), data: data);
    return _map(res.data);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await dio.delete(_p(path));
    return _map(res.data);
  }

  Future<Uint8List> bytes(String path) async {
    final res = await dio.get<List<int>>(_p(path), options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(res.data ?? const []);
  }

  /// Jalur selalu diawali '/', sama seperti pemanggilan di Tahap 1.
  static String _p(String path) => path.startsWith('/') ? path : '/$path';

  static Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{'data': data};
}

final t2ApiProvider = Provider<T2Api>((ref) => T2Api(ref.watch(apiClientProvider)));

/// Pesan galat ramah pengguna (memakai helper core).
String t2Error(Object e) => apiErrorMessage(e);

List<Map<String, dynamic>> asList(dynamic v) =>
    (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Map<String, dynamic> asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
