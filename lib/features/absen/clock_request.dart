import 'dart:convert';

/// Satu absen yang sudah diambil di HP (selfie + lokasi) dan menunggu dikirim.
/// Disimpan di antrean lokal sampai server menjawab, sehingga absen saat
/// tanpa sinyal tetap terkirim dengan jam saat tombol ditekan.
class ClockRequest {
  ClockRequest({
    required this.clientUuid,
    required this.type,
    required this.capturedAt,
    required this.photoPath,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.isMockLocation,
    required this.isRooted,
    this.wifiSsid,
    this.wifiBssid,
    this.note,
    this.attempts = 0,
    this.lastError,
  });

  final String clientUuid;

  /// 'in' | 'out'
  final String type;
  final DateTime capturedAt;
  final String photoPath;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool isMockLocation;
  final bool isRooted;
  final String? wifiSsid;
  final String? wifiBssid;
  final String? note;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'type': type,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'photo_path': photoPath,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'is_mock_location': isMockLocation,
        'is_rooted': isRooted,
        'wifi_ssid': wifiSsid,
        'wifi_bssid': wifiBssid,
        'note': note,
        'attempts': attempts,
        'last_error': lastError,
      };

  factory ClockRequest.fromJson(Map<String, dynamic> j) => ClockRequest(
        clientUuid: j['client_uuid'] as String,
        type: j['type'] as String,
        capturedAt: DateTime.parse(j['captured_at'] as String).toLocal(),
        photoPath: j['photo_path'] as String,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        isMockLocation: j['is_mock_location'] as bool? ?? false,
        isRooted: j['is_rooted'] as bool? ?? false,
        wifiSsid: j['wifi_ssid'] as String?,
        wifiBssid: j['wifi_bssid'] as String?,
        note: j['note'] as String?,
        attempts: j['attempts'] as int? ?? 0,
        lastError: j['last_error'] as String?,
      );

  static String encodeList(List<ClockRequest> items) => jsonEncode(items.map((e) => e.toJson()).toList());

  static List<ClockRequest> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => ClockRequest.fromJson((e as Map).cast<String, dynamic>())).toList();
  }
}
