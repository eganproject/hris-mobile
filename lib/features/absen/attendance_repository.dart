import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'attendance_models.dart';
import 'clock_request.dart';

class AttendanceRepository {
  AttendanceRepository(this._dio);

  final Dio _dio;

  Future<AttendanceStatusDto> status() async {
    final res = await _dio.get('/attendance/status');
    return AttendanceStatusDto.fromJson((res.data['data'] as Map).cast<String, dynamic>());
  }

  /// Kirim satu absen. Server menjawab 200 baik diterima maupun ditolak aturan.
  Future<ClockResult> clock(ClockRequest r) async {
    final form = FormData.fromMap({
      'client_uuid': r.clientUuid,
      'type': r.type,
      'captured_at': r.capturedAt.toUtc().toIso8601String(),
      if (r.latitude != null) 'latitude': r.latitude.toString(),
      if (r.longitude != null) 'longitude': r.longitude.toString(),
      if (r.accuracy != null) 'accuracy': r.accuracy!.toStringAsFixed(1),
      'is_mock_location': r.isMockLocation ? '1' : '0',
      'is_rooted': r.isRooted ? '1' : '0',
      if (r.wifiSsid != null) 'wifi_ssid': r.wifiSsid,
      if (r.wifiBssid != null) 'wifi_bssid': r.wifiBssid,
      if (r.note != null && r.note!.isNotEmpty) 'note': r.note,
      'photo': await MultipartFile.fromFile(r.photoPath, filename: 'selfie.jpg'),
    });
    final res = await _dio.post('/attendance/clock', data: form);
    return ClockResult.fromJson((res.data['data'] as Map).cast<String, dynamic>());
  }

  Future<HistoryMonth> history(DateTime month) async {
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final res = await _dio.get('/attendance/history', queryParameters: {'month': key});
    return HistoryMonth.fromJson((res.data['data'] as Map).cast<String, dynamic>());
  }
}

class HistoryMonth {
  HistoryMonth({required this.present, required this.late, required this.absent, required this.items});

  final int present;
  final int late;
  final int absent;
  final List<AttendanceDay> items;

  int get reviewed => items.where((d) => d.flags.isNotEmpty).length;

  factory HistoryMonth.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map).cast<String, dynamic>();
    return HistoryMonth(
      present: (s['present'] as num?)?.toInt() ?? 0,
      late: (s['late'] as num?)?.toInt() ?? 0,
      absent: (s['absent'] as num?)?.toInt() ?? 0,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => AttendanceDay.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(ref.watch(apiClientProvider)),
);

/// Status absen terkini untuk Beranda. Di-refresh setelah absen.
final attendanceStatusProvider = FutureProvider.autoDispose<AttendanceStatusDto>(
  (ref) => ref.watch(attendanceRepositoryProvider).status(),
);
