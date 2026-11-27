// Wajib update tanpa Play Store. Berkas ini SAMA di aplikasi HP
// (lib/core/update/app_update.dart) dan aplikasi tablet
// (tablet/lib/core/app_update.dart): ubah keduanya bersamaan.
//
// Alur: tanya HRIS "versi wajib minimum berapa" → bila versi terpasang di
// bawahnya, layar penghalang menutup seluruh aplikasi → "Update sekarang"
// mengunduh APK dari HRIS, cek SHA-256, lalu membuka pemasang Android
// (Android tetap minta satu ketukan "Update", dan sekali saja izin
// "Izinkan dari sumber ini"). Bagian Android ada di AppUpdateChannel.kt.
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentCode,
    required this.versionCode,
    required this.versionName,
    required this.size,
    required this.sha256,
    required this.downloadUrl,
    this.notes,
  });

  final int currentCode;
  final int versionCode;
  final String versionName;
  final int size;
  final String sha256;
  final String downloadUrl;
  final String? notes;

  String get sizeLabel => '${(size / 1024 / 1024).toStringAsFixed(0)} MB';

  /// Isi `data` dari GET app-update. Null bila tidak wajib update.
  static AppUpdateInfo? fromResponse(Map<String, dynamic> data) {
    final latest = data['latest'];
    if (data['update_required'] != true || latest is! Map) return null;
    return AppUpdateInfo(
      currentCode: (data['current_version_code'] as num).toInt(),
      versionCode: (latest['version_code'] as num).toInt(),
      versionName: latest['version_name'] as String? ?? '',
      size: (latest['size'] as num?)?.toInt() ?? 0,
      sha256: (latest['sha256'] as String? ?? '').toLowerCase(),
      downloadUrl: latest['download_url'] as String,
      notes: latest['notes'] as String?,
    );
  }
}

enum UpdatePhase { ready, downloading, needPermission, installing, failed }

class AppUpdater extends ChangeNotifier {
  AppUpdater({
    required this.checkUrl,
    this.headers,
    this.beforeInstall,
    this.recheckEvery,
    Dio? dio,
    MethodChannel? channel,
  })  : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30))),
        _channel = channel ?? const MethodChannel('cok/app_update');

  /// Alamat cek versi tanpa query, mis. https://cok-hris.com/api/app-update/employee.
  final String checkUrl;

  /// Header tambahan untuk cek + unduh (tablet: token Bearer).
  final Map<String, String> Function()? headers;

  /// Dipanggil tepat sebelum pemasang Android dibuka (tablet: lepas sematan layar).
  final Future<void> Function()? beforeInstall;

  /// Cek berkala untuk aplikasi yang jarang ditutup (tablet).
  final Duration? recheckEvery;

  final Dio _dio;
  final MethodChannel _channel;

  AppUpdateInfo? required;
  UpdatePhase phase = UpdatePhase.ready;
  int received = 0;
  int total = 0;
  String? error;

  CancelToken? _cancel;
  DateTime? _lastCheck;
  bool _checking = false;
  Timer? _timer;

  bool get supported => Platform.isAndroid;
  double? get progress => total > 0 ? (received / total).clamp(0, 1) : null;

  void startPeriodic() {
    final every = recheckEvery;
    if (every == null || _timer != null) return;
    _timer = Timer.periodic(every, (_) => check(force: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancel?.cancel();
    super.dispose();
  }

  Map<String, String> get _headers => {'Accept': 'application/json', ...?headers?.call()};

  Future<void> check({bool force = false}) async {
    if (!supported || _checking) return;
    if (phase == UpdatePhase.downloading || phase == UpdatePhase.installing) return;
    final last = _lastCheck;
    if (!force && last != null && DateTime.now().difference(last) < const Duration(seconds: 30)) return;
    _checking = true;
    try {
      final code = await _channel.invokeMethod<int>('versionCode') ?? 0;
      final res = await _dio.get<Map<String, dynamic>>(
        checkUrl,
        queryParameters: {'version_code': code},
        options: Options(headers: _headers),
      );
      _lastCheck = DateTime.now();
      final data = (res.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) return;
      final info = AppUpdateInfo.fromResponse(data);
      if (info?.versionCode != required?.versionCode) {
        required = info;
        phase = UpdatePhase.ready;
        error = null;
        notifyListeners();
      }
    } catch (_) {
      // Tanpa internet / server sibuk: biarkan seperti sebelumnya, cek lagi nanti.
    } finally {
      _checking = false;
    }
  }

  /// Aplikasi kembali ke depan (dari pengaturan izin, atau pemasang dibatalkan).
  Future<void> onResume() async {
    if (phase == UpdatePhase.needPermission) {
      if (await _canInstall()) {
        await _install();
      }
      return;
    }
    if (phase == UpdatePhase.installing) {
      // Pemasang ditutup tanpa update: tampilkan lagi tombolnya.
      phase = UpdatePhase.ready;
      notifyListeners();
    }
    await check();
  }

  Future<void> start() async {
    final info = required;
    if (info == null || phase == UpdatePhase.downloading) return;
    error = null;
    try {
      final path = await _channel.invokeMethod<String>('updateFilePath');
      if (path == null) throw Exception('Folder unduhan tidak tersedia.');
      final file = File(path);

      if (!await _matches(file, info.sha256)) {
        phase = UpdatePhase.downloading;
        received = 0;
        total = info.size;
        notifyListeners();

        _cancel = CancelToken();
        if (await file.exists()) await file.delete();
        await _dio.download(
          info.downloadUrl,
          path,
          cancelToken: _cancel,
          options: Options(headers: _headers, receiveTimeout: const Duration(minutes: 5)),
          onReceiveProgress: (got, all) {
            received = got;
            if (all > 0) total = all;
            notifyListeners();
          },
        );
        if (!await _matches(file, info.sha256)) {
          await file.delete();
          throw Exception('Berkas update rusak saat diunduh. Coba lagi.');
        }
      }

      if (!await _canInstall()) {
        phase = UpdatePhase.needPermission;
        notifyListeners();
        return;
      }
      await _install();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        phase = UpdatePhase.ready;
      } else {
        phase = UpdatePhase.failed;
        error = e.response == null
            ? 'Unduhan terputus. Periksa internet lalu coba lagi.'
            : 'Server menolak unduhan (${e.response?.statusCode}). Coba lagi nanti.';
      }
      notifyListeners();
    } catch (e) {
      phase = UpdatePhase.failed;
      error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void cancel() => _cancel?.cancel();

  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  Future<bool> _canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _install() async {
    try {
      final path = await _channel.invokeMethod<String>('updateFilePath');
      await beforeInstall?.call();
      await _channel.invokeMethod('install', {'path': path});
      phase = UpdatePhase.installing;
    } catch (e) {
      phase = UpdatePhase.failed;
      error = 'Pemasang Android tidak bisa dibuka. Coba lagi.';
    }
    notifyListeners();
  }

  static Future<bool> _matches(File file, String expected) async {
    if (expected.isEmpty || !await file.exists()) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }
}

/// Bungkus seluruh aplikasi (MaterialApp.builder). Bila wajib update, layar
/// penghalang menutup semua layar di bawahnya sampai aplikasi diupdate.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.updater, required this.child, this.appName = 'HRIS COK'});

  final AppUpdater updater;
  final Widget child;
  final String appName;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.updater.check(force: true);
    widget.updater.startPeriodic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.updater.onResume();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.updater,
      builder: (context, child) {
        final info = widget.updater.required;
        if (info == null) return child!;
        return Stack(children: [
          // Layar di bawahnya tetap hidup (tidak di-reset), hanya tertutup.
          ExcludeSemantics(child: IgnorePointer(child: child!)),
          Positioned.fill(child: UpdateRequiredScreen(updater: widget.updater, info: info, appName: widget.appName)),
        ]);
      },
      child: widget.child,
    );
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.updater, required this.info, this.appName = 'HRIS COK'});

  final AppUpdater updater;
  final AppUpdateInfo info;
  final String appName;

  static const _navy = Color(0xFF16255A);
  static const _yellow = Color(0xFFF9AE05);

  @override
  Widget build(BuildContext context) {
    final permission = updater.phase == UpdatePhase.needPermission;
    return Material(
      color: permission ? const Color(0xFFF3F5F9) : _navy,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: permission ? _permission(context) : _main(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _main(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final phase = updater.phase;
    final notes = info.notes?.trim();
    final white = text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85), height: 1.5);

    if (phase == UpdatePhase.downloading) {
      final p = updater.progress;
      String mb(int b) => (b / 1024 / 1024).toStringAsFixed(0);
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Mengunduh update', textAlign: TextAlign.center, style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(p == null ? '…' : '${(p * 100).round()}%',
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: p, minHeight: 8, color: _yellow, backgroundColor: Colors.white.withValues(alpha: 0.16)),
        ),
        const SizedBox(height: 8),
        Text(updater.total > 0 ? '${mb(updater.received)} dari ${mb(updater.total)} MB' : '${mb(updater.received)} MB',
            textAlign: TextAlign.center, style: white),
        const SizedBox(height: 28),
        Text('Jangan tutup aplikasi sampai selesai.', textAlign: TextAlign.center, style: white?.copyWith(fontSize: 12)),
        TextButton(onPressed: updater.cancel, child: Text('Batalkan', style: TextStyle(color: Colors.white.withValues(alpha: 0.75)))),
      ]);
    }

    final installing = phase == UpdatePhase.installing;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(color: _yellow, borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.system_update_alt_rounded, color: _navy, size: 34),
        ),
      ),
      const SizedBox(height: 18),
      Text('Perlu update aplikasi', textAlign: TextAlign.center, style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(
        installing
            ? 'Ikuti layar Android, lalu ketuk "Update" atau "Instal". Data dan login kamu tidak hilang.'
            : 'Versi $appName di perangkat ini sudah tidak bisa dipakai. Update dulu untuk lanjut.',
        textAlign: TextAlign.center,
        style: white,
      ),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _chip('Versi kamu: build ${info.currentCode}', false),
        _chip('Terbaru: build ${info.versionCode}', true),
      ]),
      if (notes != null && notes.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YANG BARU', style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.65), letterSpacing: 0.8, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(notes, style: white?.copyWith(fontSize: 13)),
          ]),
        ),
      ],
      if (phase == UpdatePhase.failed && updater.error != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(12)),
          child: Text(updater.error!, style: text.bodyMedium?.copyWith(color: const Color(0xFFB42318))),
        ),
      ],
      const SizedBox(height: 28),
      SizedBox(
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _yellow,
            foregroundColor: _navy,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          onPressed: updater.start,
          child: Text(installing ? 'Pasang lagi' : (phase == UpdatePhase.failed ? 'Coba lagi' : 'Update sekarang')),
        ),
      ),
      const SizedBox(height: 10),
      Text('Ukuran ${info.sizeLabel}. Pakai Wi-Fi bila bisa.', textAlign: TextAlign.center, style: white?.copyWith(fontSize: 12)),
    ]);
  }

  Widget _permission(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget step(String n, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle),
              child: Text(n, style: text.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: text.bodyMedium?.copyWith(height: 1.45))),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Satu langkah, sekali saja', style: text.headlineSmall?.copyWith(color: _navy, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('Android minta izin agar $appName boleh memasang update. Cukup sekali di perangkat ini.',
          style: text.bodyMedium?.copyWith(color: const Color(0xFF667085), height: 1.5)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEAECF0))),
        child: Column(children: [
          step('1', 'Ketuk "Buka pengaturan".'),
          step('2', 'Nyalakan "Izinkan dari sumber ini".'),
          step('3', 'Tekan Kembali. Pemasangan lanjut sendiri.'),
        ]),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          onPressed: updater.openPermissionSettings,
          child: const Text('Buka pengaturan'),
        ),
      ),
    ]);
  }

  Widget _chip(String label, bool highlight) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: highlight ? _yellow : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: highlight ? FontWeight.w700 : FontWeight.w500, color: highlight ? _navy : Colors.white)),
      );
}
