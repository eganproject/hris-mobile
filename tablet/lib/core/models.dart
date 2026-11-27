import 'dart:typed_data';

import '../face/matcher.dart';

class TabletSettings {
  const TabletSettings({
    this.livenessEnabled = true,
    this.livenessPass = 0.6,
    this.livenessDoubtful = 0.85,
    this.matchThreshold = 0.40,
    this.matchMargin = 0.06,
    this.consecutiveFrames = 3,
    this.repeatIgnoreSeconds = 60,
    this.pinEnabled = true,
    this.sessionMaxMinutes = 1430,
    this.idleMinutes = 1,
  });

  factory TabletSettings.fromJson(Map<String, dynamic> j) => TabletSettings(
        livenessEnabled: j['liveness_enabled'] as bool? ?? true,
        livenessPass: (j['liveness_pass'] as num?)?.toDouble() ?? 0.6,
        livenessDoubtful: (j['liveness_doubtful'] as num?)?.toDouble() ?? 0.85,
        matchThreshold: (j['match_threshold'] as num?)?.toDouble() ?? 0.40,
        matchMargin: (j['match_margin'] as num?)?.toDouble() ?? 0.06,
        consecutiveFrames: (j['consecutive_frames'] as num?)?.toInt() ?? 3,
        repeatIgnoreSeconds: (j['repeat_ignore_seconds'] as num?)?.toInt() ?? 60,
        pinEnabled: j['pin_enabled'] as bool? ?? true,
        sessionMaxMinutes: (j['session_max_minutes'] as num?)?.toInt() ?? 1430,
        idleMinutes: (j['idle_minutes'] as num?)?.toInt() ?? 1,
      );

  final bool livenessEnabled;
  final double livenessPass;
  final double livenessDoubtful;
  final double matchThreshold;
  final double matchMargin;
  final int consecutiveFrames;
  final int repeatIgnoreSeconds;
  final bool pinEnabled;
  final int sessionMaxMinutes;

  /// Menit tanpa wajah sebelum layar istirahat muncul (0 = tidak pernah).
  final int idleMinutes;
}

class Schedule {
  const Schedule(this.start, this.end, this.lateTolerance);
  final String start;
  final String end;
  final int lateTolerance;
}

class Employee {
  Employee({
    required this.id,
    required this.name,
    required this.nik,
    required this.position,
    required this.initials,
    required this.faces,
    required this.pinHash,
    required this.schedule,
    required this.openClockIn,
    required this.todayClockIn,
    required this.todayClockOut,
  });

  factory Employee.fromJson(Map<String, dynamic> j) {
    final s = j['schedule'] as Map<String, dynamic>?;
    DateTime? t(String key) => j[key] == null ? null : DateTime.tryParse(j[key] as String)?.toLocal();
    return Employee(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
      nik: j['nik'] as String? ?? '',
      position: j['position'] as String?,
      initials: j['initials'] as String? ?? '',
      faces: ((j['faces'] as List?) ?? const []).map((e) => decodeEmbedding(e as String)).whereType<Float32List>().toList(),
      pinHash: j['pin_hash'] as String?,
      schedule: s == null ? null : Schedule(s['start'] as String, s['end'] as String, (s['late_tolerance_minutes'] as num?)?.toInt() ?? 0),
      openClockIn: t('open_clock_in'),
      todayClockIn: t('today_clock_in'),
      todayClockOut: t('today_clock_out'),
    );
  }

  final int id;
  final String name;
  final String nik;
  final String? position;
  final String initials;
  final List<Float32List> faces;
  final String? pinHash;
  final Schedule? schedule;
  final DateTime? openClockIn;
  final DateTime? todayClockIn;
  final DateTime? todayClockOut;

  bool get hasFace => faces.isNotEmpty;
}

class RecentItem {
  const RecentItem({required this.employeeId, required this.name, required this.initials, required this.type, required this.at});

  factory RecentItem.fromJson(Map<String, dynamic> j) => RecentItem(
        employeeId: (j['employee_id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        initials: j['initials'] as String? ?? '',
        type: j['type'] as String? ?? 'in',
        at: DateTime.tryParse(j['at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  final int employeeId;
  final String name;
  final String initials;
  final String type;
  final DateTime at;
}

class SyncData {
  SyncData({
    required this.tabletName,
    required this.branchName,
    required this.company,
    required this.hrPinHash,
    required this.settings,
    required this.employees,
    required this.recent,
    required this.present,
    required this.total,
    required this.serverTime,
  });

  factory SyncData.fromJson(Map<String, dynamic> j) {
    final tablet = j['tablet'] as Map<String, dynamic>? ?? const {};
    final branch = tablet['branch'] as Map<String, dynamic>? ?? const {};
    final stats = j['stats'] as Map<String, dynamic>? ?? const {};
    return SyncData(
      tabletName: tablet['name'] as String? ?? '',
      branchName: branch['name'] as String? ?? '',
      company: j['company'] as String? ?? 'Cahaya Optima Karya',
      hrPinHash: tablet['hr_pin_hash'] as String?,
      settings: TabletSettings.fromJson(j['settings'] as Map<String, dynamic>? ?? const {}),
      employees: ((j['employees'] as List?) ?? const []).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList(),
      recent: ((j['recent'] as List?) ?? const []).map((e) => RecentItem.fromJson(e as Map<String, dynamic>)).toList(),
      present: (stats['present'] as num?)?.toInt() ?? 0,
      total: (stats['total'] as num?)?.toInt() ?? 0,
      serverTime: DateTime.tryParse(j['server_time'] as String? ?? '')?.toLocal(),
    );
  }

  final String tabletName;
  final String branchName;
  final String company;
  final String? hrPinHash;
  final TabletSettings settings;
  final List<Employee> employees;
  final List<RecentItem> recent;
  final int present;
  final int total;
  final DateTime? serverTime;

  late final Map<int, Employee> byId = {for (final e in employees) e.id: e};

  late final List<GalleryEntry> gallery = [
    for (final e in employees)
      if (e.hasFace) GalleryEntry(e.id, e.faces),
  ];

  int get enrolledCount => gallery.length;
}

/// Satu absen yang menunggu dikirim (disimpan di tablet sampai server menerima).
class PendingRecord {
  PendingRecord({
    required this.uuid,
    required this.employeeId,
    required this.employeeName,
    required this.capturedAt,
    required this.method,
    required this.predictedType,
    this.requestedType,
    this.matchScore,
    this.matchMargin,
    this.livenessChecked = false,
    this.livenessScore,
    this.notMe = false,
    this.photoPath,
    this.attempts = 0,
    this.lastError,
  });

  factory PendingRecord.fromJson(Map<String, dynamic> j) => PendingRecord(
        uuid: j['uuid'] as String,
        employeeId: (j['employee_id'] as num).toInt(),
        employeeName: j['employee_name'] as String? ?? '',
        capturedAt: DateTime.parse(j['captured_at'] as String),
        method: j['method'] as String? ?? 'face',
        predictedType: j['predicted_type'] as String? ?? 'in',
        requestedType: j['requested_type'] as String?,
        matchScore: (j['match_score'] as num?)?.toDouble(),
        matchMargin: (j['match_margin'] as num?)?.toDouble(),
        livenessChecked: j['liveness_checked'] as bool? ?? false,
        livenessScore: (j['liveness_score'] as num?)?.toDouble(),
        notMe: j['not_me'] as bool? ?? false,
        photoPath: j['photo_path'] as String?,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        lastError: j['last_error'] as String?,
      );

  final String uuid;
  final int employeeId;
  final String employeeName;
  final DateTime capturedAt;
  final String method;
  final String predictedType;

  /// Pilihan karyawan lewat tombol Absen Masuk / Absen Pulang (null = versi lama).
  final String? requestedType;
  final double? matchScore;
  final double? matchMargin;
  final bool livenessChecked;
  final double? livenessScore;
  final bool notMe;
  final String? photoPath;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'method': method,
        'predicted_type': predictedType,
        'requested_type': requestedType,
        'match_score': matchScore,
        'match_margin': matchMargin,
        'liveness_checked': livenessChecked,
        'liveness_score': livenessScore,
        'not_me': notMe,
        'photo_path': photoPath,
        'attempts': attempts,
        'last_error': lastError,
      };
}
