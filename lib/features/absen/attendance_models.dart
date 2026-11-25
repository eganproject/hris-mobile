import '../../core/util/format.dart';

/// GET /attendance/status
class AttendanceStatusDto {
  AttendanceStatusDto({
    required this.serverTime,
    required this.workDate,
    required this.sessionOpen,
    this.clockInAt,
    this.expiresAt,
    required this.nextAction,
    this.attendance,
    required this.isDayOff,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    required this.mode,
    required this.modeLabel,
    this.location,
    required this.sessionMaxMinutes,
    required this.blinkTimeoutSeconds,
  });

  final DateTime serverTime;
  final DateTime workDate;
  final bool sessionOpen;
  final DateTime? clockInAt;
  final DateTime? expiresAt;

  /// 'in' atau 'out'.
  final String nextAction;
  final AttendanceDay? attendance;
  final bool isDayOff;
  final String? shiftName;
  final String? shiftStart;
  final String? shiftEnd;

  /// office | wfh | business_trip
  final String mode;
  final String modeLabel;
  final OfficeLocation? location;
  final int sessionMaxMinutes;
  final int blinkTimeoutSeconds;

  bool get isRemote => mode != 'office';

  String get shiftLabel {
    if (shiftName == null) return isDayOff ? 'Libur' : 'Tanpa jadwal';
    return '$shiftName · $shiftStart – $shiftEnd';
  }

  factory AttendanceStatusDto.fromJson(Map<String, dynamic> j) {
    final session = (j['session'] as Map).cast<String, dynamic>();
    final schedule = (j['schedule'] as Map).cast<String, dynamic>();
    final shift = (schedule['shift'] as Map?)?.cast<String, dynamic>();
    final settings = (j['settings'] as Map).cast<String, dynamic>();
    final loc = (j['location'] as Map?)?.cast<String, dynamic>();
    final att = (j['attendance'] as Map?)?.cast<String, dynamic>();
    return AttendanceStatusDto(
      serverTime: DateTime.parse(j['server_time'] as String).toLocal(),
      workDate: DateTime.parse(j['work_date'] as String),
      sessionOpen: session['open'] as bool? ?? false,
      clockInAt: Fmt.parse(session['clock_in_at'] as String?),
      expiresAt: Fmt.parse(session['expires_at'] as String?),
      nextAction: j['next_action'] as String? ?? 'in',
      attendance: att == null ? null : AttendanceDay.fromJson(att),
      isDayOff: schedule['is_day_off'] as bool? ?? false,
      shiftName: shift?['name'] as String?,
      shiftStart: shift?['start'] as String?,
      shiftEnd: shift?['end'] as String?,
      mode: j['mode'] as String? ?? 'office',
      modeLabel: j['mode_label'] as String? ?? 'Kantor',
      location: loc == null ? null : OfficeLocation.fromJson(loc),
      sessionMaxMinutes: settings['session_max_minutes'] as int? ?? 1430,
      blinkTimeoutSeconds: settings['blink_timeout_seconds'] as int? ?? 10,
    );
  }
}

class OfficeLocation {
  OfficeLocation({
    required this.name,
    required this.enabled,
    this.latitude,
    this.longitude,
    required this.radiusM,
    required this.strict,
    required this.hasWifi,
  });

  final String name;
  final bool enabled;
  final double? latitude;
  final double? longitude;
  final int radiusM;
  final bool strict;
  final bool hasWifi;

  bool get hasGeofence => latitude != null && longitude != null;

  factory OfficeLocation.fromJson(Map<String, dynamic> j) => OfficeLocation(
        name: j['name'] as String? ?? '-',
        enabled: j['enabled'] as bool? ?? false,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        radiusM: (j['radius_m'] as num?)?.toInt() ?? 100,
        strict: j['strict'] as bool? ?? false,
        hasWifi: j['has_wifi'] as bool? ?? false,
      );
}

/// Satu baris absensi harian.
class AttendanceDay {
  AttendanceDay({
    required this.id,
    required this.workDate,
    required this.status,
    required this.statusLabel,
    this.shift,
    this.clockIn,
    this.clockOut,
    required this.lateMinutes,
    required this.workMinutes,
    this.flags = const [],
  });

  final int id;
  final DateTime workDate;
  final String status;
  final String statusLabel;
  final String? shift;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final int lateMinutes;
  final int workMinutes;
  final List<String> flags;

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        id: j['id'] as int,
        workDate: DateTime.parse(j['work_date'] as String),
        status: j['status'] as String,
        statusLabel: j['status_label'] as String? ?? j['status'] as String,
        shift: j['shift'] as String?,
        clockIn: Fmt.parse(j['clock_in'] as String?),
        clockOut: Fmt.parse(j['clock_out'] as String?),
        lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
        workMinutes: (j['work_minutes'] as num?)?.toInt() ?? 0,
        flags: ((j['flags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// Hasil POST /attendance/clock.
class ClockResult {
  ClockResult({
    required this.clientUuid,
    required this.type,
    required this.accepted,
    this.rejectCode,
    required this.message,
    required this.capturedAt,
    this.branch,
    this.distanceM,
    this.withinRadius,
    required this.blinkVerified,
    required this.flagLabels,
    required this.needsReview,
    required this.modeLabel,
  });

  final String clientUuid;
  final String type;
  final bool accepted;
  final String? rejectCode;
  final String message;
  final DateTime capturedAt;
  final String? branch;
  final int? distanceM;
  final bool? withinRadius;
  final bool blinkVerified;
  final List<String> flagLabels;
  final bool needsReview;
  final String modeLabel;

  factory ClockResult.fromJson(Map<String, dynamic> j) => ClockResult(
        clientUuid: j['client_uuid'] as String,
        type: j['type'] as String,
        accepted: j['result'] == 'accepted',
        rejectCode: j['reject_code'] as String?,
        message: j['message'] as String? ?? '',
        capturedAt: DateTime.parse(j['captured_at'] as String).toLocal(),
        branch: j['branch'] as String?,
        distanceM: (j['distance_m'] as num?)?.toInt(),
        withinRadius: j['within_radius'] as bool?,
        blinkVerified: j['blink_verified'] as bool? ?? false,
        flagLabels: ((j['flag_labels'] as List?) ?? const []).map((e) => e.toString()).toList(),
        needsReview: j['needs_review'] as bool? ?? false,
        modeLabel: j['mode_label'] as String? ?? '',
      );
}
