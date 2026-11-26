import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';
import 'predict.dart';

class _Event {
  _Event(this.employeeId, this.event, this.name, this.initials);
  final int employeeId;
  final LocalEvent event;
  final String name;
  final String initials;
  DateTime? sentAt;
}

/// Status tablet: token, data sinkron (disimpan untuk offline), antrean absen,
/// dan absen yang tercatat di tablet ini sejak sinkron terakhir.
class TabletController extends ChangeNotifier {
  TabletController({TabletApi? api}) : api = api ?? TabletApi();

  final TabletApi api;
  late SharedPreferences _prefs;
  late Directory _dir;

  SyncData? data;
  bool online = false;
  bool loaded = false;
  DateTime? lastSyncAt;
  String? lastError;

  /// Pesan untuk layar pemasangan bila tablet dicabut dari web.
  String? unpairedReason;

  final List<PendingRecord> queue = [];
  final List<PendingRecord> failed = [];
  final List<_Event> _events = [];

  Timer? _syncTimer;
  Timer? _flushTimer;
  bool _flushing = false;
  bool _syncing = false;

  bool get paired => api.token != null;
  int get queueCount => queue.length;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _dir = await getApplicationSupportDirectory();
    api.token = _prefs.getString('token');

    final cached = File('${_dir.path}/sync.json');
    if (cached.existsSync()) {
      try {
        data = SyncData.fromJson(jsonDecode(cached.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {}
    }

    final q = File('${_dir.path}/queue.json');
    if (q.existsSync()) {
      try {
        final list = jsonDecode(q.readAsStringSync()) as List;
        queue.addAll(list.map((e) => PendingRecord.fromJson(e as Map<String, dynamic>)));
        for (final r in queue.where((r) => !r.notMe)) {
          _events.add(_Event(r.employeeId, LocalEvent(r.predictedType, r.capturedAt), r.employeeName, ''));
        }
      } catch (_) {}
    }

    loaded = true;
    notifyListeners();

    if (paired) _start();
  }

  void _start() {
    _syncTimer?.cancel();
    _flushTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => syncNow());
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
    unawaited(syncNow());
    unawaited(flush());
  }

  Future<void> pair(String code) async {
    String? model;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      model = '${info.manufacturer} ${info.model}'.trim();
    } catch (_) {}

    final token = await api.pair(code, deviceModel: model);
    api.token = token;
    await _prefs.setString('token', token);
    unpairedReason = null;
    await syncNow();
    _start();
    notifyListeners();
  }

  Future<void> _unpair(String reason) async {
    _syncTimer?.cancel();
    _flushTimer?.cancel();
    api.token = null;
    await _prefs.remove('token');
    unpairedReason = reason;
    online = false;
    notifyListeners();
  }

  /// Keluarkan tablet dari HRIS (menu HR). Antrean yang belum terkirim ikut hilang.
  Future<void> unpairManually() => _unpair('Tablet dikeluarkan dari menu HR.');

  Future<void> syncNow() async {
    if (!paired || _syncing) return;
    _syncing = true;
    final started = DateTime.now();
    try {
      final json = await api.sync(queue: queue.length);
      data = SyncData.fromJson(json);
      File('${_dir.path}/sync.json').writeAsStringSync(jsonEncode(json));
      online = true;
      lastSyncAt = DateTime.now();
      lastError = null;
      // Absen yang sudah terkirim sebelum sinkron ini sudah tercermin di data server.
      _events.removeWhere((e) => e.sentAt != null && e.sentAt!.isBefore(started));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _unpair(e.message);
      } else {
        online = !e.isNetwork;
        lastError = e.message;
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  List<LocalEvent> localEventsFor(int employeeId) =>
      [for (final e in _events.where((e) => e.employeeId == employeeId)) e.event];

  Predicted predict(Employee e, DateTime now) => predictAction(e, localEventsFor(e.id), now, data?.settings ?? const TabletSettings());

  ChoiceCheck checkChoice(Employee e, DateTime now, String chosen) =>
      checkChosen(e, localEventsFor(e.id), now, data?.settings ?? const TabletSettings(), chosen);

  /// Pilihan bawaan tombol Masuk/Pulang menurut jam (lihat [defaultChoice]).
  String defaultChoiceAt(DateTime now) => defaultChoice(data?.employees ?? const [], now);

  /// Daftar "Baru saja absen": dari server + yang baru tercatat di tablet ini.
  List<RecentItem> recent({int limit = 3}) {
    final today = DateTime.now();
    final items = <RecentItem>[
      for (final e in _events)
        if (e.event.at.day == today.day && e.event.at.month == today.month)
          RecentItem(employeeId: e.employeeId, name: _short(e.name), initials: e.initials, type: e.event.type, at: e.event.at),
      ...?data?.recent,
    ];
    final seen = <String>{};
    final unique = <RecentItem>[];
    for (final r in items..sort((a, b) => b.at.compareTo(a.at))) {
      final key = '${r.employeeId}-${r.type}-${r.at.millisecondsSinceEpoch ~/ 60000}';
      if (seen.add(key)) unique.add(r);
    }
    return unique.take(limit).toList();
  }

  int get presentCount {
    final d = data;
    if (d == null) return 0;
    final extra = _events
        .where((e) => e.event.type == 'in' && e.sentAt == null && d.byId[e.employeeId]?.todayClockIn == null)
        .map((e) => e.employeeId)
        .toSet()
        .length;
    return d.present + extra;
  }

  /// Simpan absen ke antrean lalu coba kirim.
  Future<void> record(PendingRecord r, {required Employee employee}) async {
    queue.add(r);
    if (!r.notMe) {
      _events.add(_Event(employee.id, LocalEvent(r.predictedType, r.capturedAt), employee.name, employee.initials));
    }
    _saveQueue();
    notifyListeners();
    unawaited(flush());
  }

  Future<String> savePhoto(Uint8List jpeg, String uuid) async {
    final dir = Directory('${_dir.path}/photos')..createSync(recursive: true);
    final f = File('${dir.path}/$uuid.jpg');
    await f.writeAsBytes(jpeg);
    return f.path;
  }

  Future<void> flush() async {
    if (!paired || _flushing || queue.isEmpty) return;
    _flushing = true;
    try {
      while (queue.isNotEmpty) {
        final r = queue.first;
        try {
          await api.sendAttendance(r);
          online = true;
          _done(r);
          for (final e in _events.where((e) => e.employeeId == r.employeeId && e.event.at == r.capturedAt)) {
            e.sentAt = DateTime.now();
          }
        } on ApiException catch (e) {
          if (e.isNetwork) {
            online = false;
            break;
          }
          if (e.isUnauthorized) {
            await _unpair(e.message);
            break;
          }
          r.attempts++;
          r.lastError = e.message;
          if (r.attempts >= 3 || (e.status ?? 500) < 500) {
            // Ditolak server (mis. karyawan sudah nonaktif): jangan menyumbat antrean.
            failed.insert(0, r);
            if (failed.length > 50) failed.removeLast();
            _done(r);
            _events.removeWhere((ev) => ev.employeeId == r.employeeId && ev.event.at == r.capturedAt);
          } else {
            break;
          }
        }
      }
    } finally {
      _flushing = false;
      _saveQueue();
      notifyListeners();
    }
  }

  void _done(PendingRecord r) {
    queue.remove(r);
    final p = r.photoPath;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  void _saveQueue() {
    File('${_dir.path}/queue.json').writeAsStringSync(jsonEncode(queue.map((e) => e.toJson()).toList()));
  }

  static String _short(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? '${parts[0]} ${parts[1].substring(0, 1)}.' : name;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}
