import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../core/widgets/ui.dart';
import 'attendance_models.dart';
import 'attendance_repository.dart';
import 'clock_request.dart';
import 'device_checks.dart';
import 'offline_queue.dart';
import 'selfie_camera.dart';

enum _Step { checking, outsideRadius, camera, sending, success, rejected, queued, error }

/// Alur absen masuk/pulang: cek lokasi & HP → (di luar area: alasan) →
/// selfie → kirim (atau antre bila offline) → hasil.
class ClockFlowPage extends ConsumerStatefulWidget {
  const ClockFlowPage({super.key, required this.type});

  /// 'in' atau 'out'
  final String type;

  @override
  ConsumerState<ClockFlowPage> createState() => _ClockFlowPageState();
}

class _ClockFlowPageState extends ConsumerState<ClockFlowPage> {
  final _cameraKey = GlobalKey<SelfieCameraState>();
  final _noteController = TextEditingController();

  _Step _step = _Step.checking;
  SelfiePhase _phase = SelfiePhase.starting;
  AttendanceStatusDto? _status;
  LocationSnapshot? _location;
  double? _distance;
  String? _errorMessage;
  ClockResult? _result;
  ClockRequest? _request;

  bool get _isIn => widget.type == 'in';
  String get _title => _isIn ? 'Absen Masuk' : 'Absen Pulang';

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _step = _Step.checking;
      _errorMessage = null;
    });

    AttendanceStatusDto? status;
    try {
      status = await ref.read(attendanceRepositoryProvider).status();
    } catch (_) {
      status = null; // offline: tetap boleh absen, server menilai saat terkirim
    }
    final location = await DeviceChecks.read();
    if (!mounted) return;

    _status = status;
    _location = location;

    final office = status?.location;
    if (status != null && !status.isRemote) {
      if (office == null || !office.enabled) {
        setState(() {
          _step = _Step.error;
          _errorMessage = 'Lokasi kerjamu belum memakai absen lewat aplikasi. Gunakan mesin absen, atau hubungi HR.';
        });
        return;
      }
      _distance = location.distanceTo(office.latitude, office.longitude);
      if (!location.isMocked && !location.isRooted && _distance != null && _distance! > office.radiusM) {
        setState(() => _step = _Step.outsideRadius);
        return;
      }
    }

    setState(() => _step = _Step.camera);
  }

  Future<void> _submit(XFile photo) async {
    setState(() => _step = _Step.sending);

    final uuid = const Uuid().v4();
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/absen-antre');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final saved = await File(photo.path).copy('${dir.path}/$uuid.jpg');
    try {
      File(photo.path).deleteSync();
    } catch (_) {}

    final loc = _location;
    final request = ClockRequest(
      clientUuid: uuid,
      type: widget.type,
      capturedAt: DateTime.now(),
      photoPath: saved.path,
      latitude: loc?.position?.latitude,
      longitude: loc?.position?.longitude,
      accuracy: loc?.position?.accuracy,
      isMockLocation: loc?.isMocked ?? false,
      isRooted: loc?.isRooted ?? false,
      wifiSsid: loc?.wifiSsid,
      wifiBssid: loc?.wifiBssid,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    _request = request;

    final result = await ref.read(offlineQueueProvider.notifier).submit(request);
    if (!mounted) return;
    ref.invalidate(attendanceStatusProvider);

    if (result == null) {
      final pending = ref.read(offlineQueueProvider).items.any((r) => r.clientUuid == uuid);
      setState(() {
        _step = pending ? _Step.queued : _Step.error;
        _errorMessage = pending ? null : 'Absen tidak bisa diproses. Coba lagi.';
      });
      return;
    }
    if (result.rejectCode == 'consent_required') {
      context.go('/daftar-hp');
      return;
    }
    setState(() {
      _result = result;
      _step = result.accepted ? _Step.success : _Step.rejected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.checking || _Step.sending => _loading(_step == _Step.checking ? 'Memeriksa lokasi dan HP…' : 'Mengirim absen…'),
      _Step.outsideRadius => _outsideRadius(),
      _Step.camera => _camera(),
      _Step.success => _success(),
      _Step.rejected => _rejected(),
      _Step.queued => _queued(),
      _Step.error => _errorScreen(),
    };
  }

  Widget _loading(String text) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            Text(text, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // --- Di luar area ---------------------------------------------------------
  Widget _outsideRadius() {
    final office = _status!.location!;
    final distance = _distance!.round();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(children: [
            const ResultIllustration(icon: Icons.location_off_outlined, color: AppColors.warning, background: Color(0xFFFFEDD5)),
            const SizedBox(height: 36),
            const Text('Di luar area kantor', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Kamu $distance m dari ${office.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              office.strict
                  ? 'Area absen ${office.radiusM} m. Lokasi ini memakai mode ketat, jadi absen hanya bisa di dalam area.'
                  : 'Area absen ${office.radiusM} m. Kamu tetap bisa absen, tapi HR akan meninjaunya dulu. Tulis alasan singkat ya.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.55),
            ),
            if (!office.strict) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _noteController,
                maxLength: 200,
                decoration: const InputDecoration(hintText: 'Mis. rapat di kantor klien'),
              ),
            ],
            const Spacer(),
            if (!office.strict)
              FilledButton(
                onPressed: () => setState(() => _step = _Step.camera),
                child: const Text('Tetap absen, kirim ke HR'),
              ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _check, child: const Text('Coba lagi saat sudah dekat')),
            TextButton(onPressed: () => context.pop(), child: const Text('Batal')),
          ]),
        ),
      ),
    );
  }

  // --- Kamera ---------------------------------------------------------------
  Widget _camera() {
    final status = _status;
    final office = status?.location;
    final loc = _location;
    final hint = switch (_phase) {
      SelfiePhase.starting => 'Menyiapkan kamera…',
      SelfiePhase.ready => 'Posisikan wajah di dalam bingkai',
      SelfiePhase.capturing => 'Mengambil foto…',
      SelfiePhase.captured => 'Foto diambil',
      SelfiePhase.error => _cameraKey.currentState?.errorMessage ?? 'Kamera bermasalah',
    };
    final locationChip = status == null
        ? 'Offline · lokasi dicatat'
        : status.isRemote
            ? '${status.modeLabel} · lokasi dicatat'
            : (_distance != null ? '${office?.name ?? 'Kantor'} · ${_distance!.round()} m' : (loc?.error ?? office?.name ?? 'Kantor'));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F20),
      body: Stack(children: [
        Positioned.fill(
          child: SelfieCamera(
            key: _cameraKey,
            onCaptured: _submit,
            onPhase: (p) => setState(() => _phase = p),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _FaceFramePainter())),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(children: [
                _roundButton(Icons.close, 'Tutup', () => context.pop()),
                Expanded(
                  child: Text(_title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                _roundButton(Icons.refresh, 'Ulangi', () => _cameraKey.currentState?.retry()),
              ]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.face_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(hint, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ]),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              StatusPill(label: locationChip, tone: PillTone.onPrimary, icon: Icons.place_outlined),
            ]),
            const SizedBox(height: 28),
            _shutter(),
            const SizedBox(height: 28),
          ]),
        ),
      ]),
    );
  }

  Widget _shutter() {
    final ready = _phase == SelfiePhase.ready;
    return Column(children: [
      Semantics(
        label: 'Ambil foto',
        button: true,
        child: InkResponse(
          onTap: ready ? () => _cameraKey.currentState?.capture() : null,
          radius: 44,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
            alignment: Alignment.center,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
              ),
              child: _phase == SelfiePhase.capturing
                  ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text('Ketuk tombol untuk mengambil selfie',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
    ]);
  }

  Widget _roundButton(IconData icon, String label, VoidCallback onTap) => Semantics(
        label: label,
        button: true,
        child: InkResponse(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );

  // --- Hasil ----------------------------------------------------------------
  Widget _success() {
    final r = _result!;
    final user = ref.read(currentUserProvider);
    final late = _status?.shiftStart != null && _isIn ? _lateLabel(r.capturedAt) : null;
    final place = r.branch != null && r.modeLabel == 'Kantor'
        ? r.branch!
        : r.modeLabel;
    final placeDetail = r.distanceM != null
        ? '${r.distanceM} m dari titik · ${r.withinRadius == true ? 'dalam area' : 'di luar area'}'
        : 'Lokasi dicatat';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        const GradientHeaderBackground(height: 470, radius: 44),
        SafeArea(
          child: Column(children: [
            const SizedBox(height: 40),
            const ResultIllustration(icon: Icons.check_rounded, color: AppColors.primary, background: Colors.white),
            const SizedBox(height: 34),
            Text('${_isIn ? 'Absen Masuk' : 'Absen Pulang'} tercatat',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            Text(Fmt.time(r.capturedAt),
                style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: -2, height: 1.05)),
            const SizedBox(height: 6),
            Text(
              _isIn
                  ? '${late ?? 'Selamat bekerja'}, ${user?.firstName ?? ''}!'
                  : 'Terima kasih untuk hari ini, ${user?.firstName ?? ''}!',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
              child: AppCard(
                radius: 26,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(children: [
                  _proofRow(Icons.face_retouching_natural, 'Selfie', 'Foto tersimpan', true),
                  const Divider(height: 1, color: AppColors.line),
                  _proofRow(Icons.place_outlined, place, placeDetail, r.withinRadius != false),
                ]),
              ),
            ),
            if (r.needsReview)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  'Ditandai untuk ditinjau HR: ${r.flagLabels.join(', ')}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: FilledButton(onPressed: () => context.go('/'), child: const Text('Selesai')),
            ),
          ]),
        ),
      ]),
    );
  }

  String? _lateLabel(DateTime at) {
    final start = _status?.shiftStart;
    if (start == null) return null;
    final parts = start.split(':');
    final scheduled = DateTime(at.year, at.month, at.day, int.parse(parts[0]), int.parse(parts[1]));
    final diff = at.difference(scheduled).inMinutes;
    return diff > 0 ? 'Terlambat $diff menit' : 'Tepat waktu';
  }

  Widget _proofRow(IconData icon, String title, String subtitle, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          Icon(ok ? Icons.check_rounded : Icons.error_outline,
              color: ok ? const Color(0xFF16A34A) : AppColors.warning),
        ]),
      );

  Widget _rejected() {
    final r = _result!;
    final security = r.rejectCode == 'mock_location' || r.rejectCode == 'rooted';
    return _messageScreen(
      icon: Icons.block,
      color: AppColors.danger,
      background: AppColors.dangerSoft,
      title: 'Absen belum bisa diproses',
      message: r.message,
      extra: security
          ? 'Juga ditolak: HP di-root/jailbreak, aplikasi yang dimodifikasi, atau HP yang belum terdaftar atas namamu. Percobaan ini tercatat dan terlihat oleh HR.'
          : null,
      primaryLabel: 'Coba lagi',
      onPrimary: _check,
      secondaryLabel: r.rejectCode == 'no_session' || r.rejectCode == 'already_clocked_in' || r.rejectCode == 'expired'
          ? 'Ajukan koreksi'
          : 'Kembali',
      onSecondary: () => r.rejectCode == 'no_session' || r.rejectCode == 'already_clocked_in' || r.rejectCode == 'expired'
          ? context.go('/koreksi')
          : context.go('/'),
    );
  }

  Widget _queued() {
    final req = _request!;
    return _messageScreen(
      icon: Icons.cloud_off_outlined,
      color: AppColors.primaryDark,
      background: AppColors.primarySoft,
      title: 'Tersimpan di HP',
      message:
          'Sinyal lagi hilang. ${_isIn ? 'Absen Masuk' : 'Absen Pulang'} ${Fmt.time(req.capturedAt)} terkirim otomatis begitu HP online, dengan jam saat kamu absen. Mencoba kirim tiap 30 detik.',
      extra: 'Jangan logout atau hapus aplikasi dulu ya.',
      primaryLabel: 'Oke, mengerti',
      onPrimary: () => context.go('/'),
      secondaryLabel: 'Coba kirim sekarang',
      onSecondary: () async {
        final results = await ref.read(offlineQueueProvider.notifier).flush();
        final r = results[req.clientUuid];
        if (!mounted) return;
        if (r != null) {
          ref.invalidate(attendanceStatusProvider);
          setState(() {
            _result = r;
            _step = r.accepted ? _Step.success : _Step.rejected;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masih belum ada sinyal.')));
        }
      },
    );
  }

  Widget _errorScreen() => _messageScreen(
        icon: Icons.info_outline,
        color: AppColors.muted,
        background: AppColors.chip,
        title: 'Belum bisa absen',
        message: _errorMessage ?? 'Terjadi kesalahan.',
        primaryLabel: 'Coba lagi',
        onPrimary: _check,
        secondaryLabel: 'Kembali',
        onSecondary: () => context.go('/'),
      );

  Widget _messageScreen({
    required IconData icon,
    required Color color,
    required Color background,
    required String title,
    required String message,
    String? extra,
    required String primaryLabel,
    required VoidCallback onPrimary,
    required String secondaryLabel,
    required VoidCallback onSecondary,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
          child: Column(children: [
            ResultIllustration(icon: icon, color: color, background: background),
            const SizedBox(height: 36),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, color: AppColors.muted, height: 1.55)),
            if (extra != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(22)),
                child: Text(extra, style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.55)),
              ),
            ],
            const Spacer(),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel)),
          ]),
        ),
      ),
    );
  }
}

/// Bingkai oval wajah.
class _FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.38), width: 248, height: 310);
    final dim = Paint()..color = const Color(0x990A0F20);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(rect);
    canvas.drawPath(path, dim);

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(rect, border);
  }

  @override
  bool shouldRepaint(covariant _FaceFramePainter oldDelegate) => false;
}
