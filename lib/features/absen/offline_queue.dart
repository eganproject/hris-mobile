import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import 'attendance_models.dart';
import 'attendance_repository.dart';
import 'clock_request.dart';

/// Keadaan antrean absen yang belum diterima server.
class QueueState {
  const QueueState({this.items = const [], this.sending = false, this.lastResult});

  final List<ClockRequest> items;
  final bool sending;

  /// Jawaban server untuk kiriman terakhir dari antrean (untuk notifikasi di
  /// Beranda, mis. absen offline yang ternyata ditolak).
  final ClockResult? lastResult;

  ClockRequest? get latest => items.isEmpty ? null : items.last;

  QueueState copyWith({List<ClockRequest>? items, bool? sending, ClockResult? lastResult}) =>
      QueueState(items: items ?? this.items, sending: sending ?? this.sending, lastResult: lastResult ?? this.lastResult);
}

/// Antrean offline: setiap absen disimpan dulu di HP dengan ID unik, lalu
/// dikirim. Bila tidak ada sinyal, dicoba lagi tiap 30 detik, saat koneksi
/// kembali, dan saat aplikasi dibuka — sampai server menjawab. Server
/// idempoten terhadap ID tersebut, jadi kiriman ganda tidak tercatat dua kali.
class OfflineQueue extends Notifier<QueueState> {
  static const _prefsKey = 'clock_queue_v1';
  static const retryInterval = Duration(seconds: 30);

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  @override
  QueueState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _connectivity?.cancel();
    });
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
    Future.microtask(_load);
    return const QueueState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(items: ClockRequest.decodeList(prefs.getString(_prefsKey)));
    _schedule();
    if (state.items.isNotEmpty) unawaited(flush());
  }

  Future<void> _persist(List<ClockRequest> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, ClockRequest.encodeList(items));
  }

  void _schedule() {
    _timer?.cancel();
    if (state.items.isEmpty) return;
    _timer = Timer.periodic(retryInterval, (_) => flush());
  }

  /// Simpan absen baru ke antrean lalu coba kirim langsung.
  /// Mengembalikan hasil server bila terkirim, atau null bila masih antre.
  Future<ClockResult?> submit(ClockRequest request) async {
    final items = [...state.items, request];
    await _persist(items);
    state = state.copyWith(items: items);
    _schedule();
    final results = await flush();
    return results[request.clientUuid];
  }

  /// Kirim semua isi antrean berurutan (urutan masuk/pulang penting).
  Future<Map<String, ClockResult>> flush() async {
    if (state.sending || state.items.isEmpty) return {};
    state = state.copyWith(sending: true);
    final repo = ref.read(attendanceRepositoryProvider);
    final results = <String, ClockResult>{};
    var remaining = [...state.items];

    try {
      for (final item in [...remaining]) {
        try {
          final result = await repo.clock(item);
          results[item.clientUuid] = result;
          remaining.remove(item);
          _deletePhoto(item.photoPath);
          state = state.copyWith(lastResult: result);
        } catch (e) {
          final err = toApiException(e);
          item.attempts++;
          item.lastError = err.message;
          // Data tidak sah (422) tidak akan pernah diterima: buang supaya antrean
          // tidak macet. Tanpa sinyal / server error / 401: simpan dan coba lagi.
          if (err.statusCode == 422 || err.statusCode == 403 && err.code != 'consent_required') {
            remaining.remove(item);
            _deletePhoto(item.photoPath);
            continue;
          }
          break;
        }
      }
    } finally {
      await _persist(remaining);
      state = state.copyWith(items: remaining, sending: false);
      _schedule();
    }
    return results;
  }

  void _deletePhoto(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

final offlineQueueProvider = NotifierProvider<OfflineQueue, QueueState>(OfflineQueue.new);
