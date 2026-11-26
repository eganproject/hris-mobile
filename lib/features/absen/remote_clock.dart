import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';
import 'attendance_repository.dart';

/// Keadaan absen selfie hari ini: {allowed, status, status_label, work_date,
/// clock_in, clock_out, next: in|out|done|null}. Hanya "allowed" pada hari WFH
/// atau dinas luar yang disetujui (aturan sama dengan web).
final remoteAttendanceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('attendance/remote');
  return asMap(res['data']);
});

/// Alur absen selfie: izin lokasi → foto selfie kamera depan → lembar konfirmasi
/// (foto + titik lokasi) → kirim. Lokasi tidak dibatasi radius, hanya dicatat.
Future<void> startRemoteClock(BuildContext context, WidgetRef ref, String side) async {
  if (!await _ensureLocationPermission(context)) return;

  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 1080,
    imageQuality: 75,
  );
  if (shot == null || !context.mounted) return;

  final bytes = await shot.readAsBytes();
  if (!context.mounted) return;

  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _RemoteClockSheet(side: side, photo: bytes, fileName: shot.name),
  );
  if (done == true) {
    ref.invalidate(remoteAttendanceProvider);
    ref.invalidate(attendanceStatusProvider);
  }
}

Future<bool> _ensureLocationPermission(BuildContext context) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) showSnack(context, 'Nyalakan GPS/lokasi di HP dulu, lalu coba lagi.', error: true);
    return false;
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.deniedForever) {
    if (!context.mounted) return false;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin lokasi dibutuhkan'),
        content: const Text('Titik lokasi dicatat saat absen WFH. Buka pengaturan aplikasi lalu izinkan akses lokasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buka pengaturan')),
        ],
      ),
    );
    if (open == true) await Geolocator.openAppSettings();
    return false;
  }
  if (perm == LocationPermission.denied) {
    if (context.mounted) showSnack(context, 'Izinkan akses lokasi untuk absen WFH.', error: true);
    return false;
  }
  return true;
}

class _RemoteClockSheet extends ConsumerStatefulWidget {
  const _RemoteClockSheet({required this.side, required this.photo, required this.fileName});
  final String side;
  final Uint8List photo;
  final String fileName;

  @override
  ConsumerState<_RemoteClockSheet> createState() => _RemoteClockSheetState();
}

class _RemoteClockSheetState extends ConsumerState<_RemoteClockSheet> {
  Position? _pos;
  String? _locError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _pos = null;
      _locError = null;
    });
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
      );
      if (mounted) setState(() => _pos = p);
    } on TimeoutException {
      // GPS lambat di dalam ruangan: pakai lokasi terakhir yang diketahui bila ada.
      final last = await Geolocator.getLastKnownPosition();
      if (!mounted) return;
      setState(() => last != null ? _pos = last : _locError = 'Lokasi belum terbaca. Coba dekat jendela, lalu ulangi.');
    } catch (_) {
      if (mounted) setState(() => _locError = 'Lokasi tidak terbaca. Pastikan GPS menyala, lalu ulangi.');
    }
  }

  Future<void> _submit() async {
    final p = _pos;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'side': widget.side,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'photo': MultipartFile.fromBytes(widget.photo, filename: widget.fileName.isEmpty ? 'selfie.jpg' : widget.fileName),
      });
      final res = await ref.read(t2ApiProvider).post('attendance/remote', data: form);
      if (!mounted) return;
      showSnack(context, (res['message'] ?? 'Absen tercatat.') as String);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, t2Error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.side == 'in';
    final h = MediaQuery.sizeOf(context).height;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(isIn ? 'Absen masuk' : 'Absen pulang', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Cek fotomu, lalu kirim. Jam absen diambil dari server.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 14),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: (h * .38).clamp(180, 380)),
              child: Image.memory(widget.photo, fit: BoxFit.contain, cacheWidth: 720),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(
              _pos != null ? Icons.location_on_rounded : (_locError != null ? Icons.location_off_outlined : Icons.my_location_rounded),
              color: _pos != null ? AppColors.success : (_locError != null ? AppColors.danger : AppColors.muted),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _pos != null
                    ? 'Lokasi tercatat · akurasi ±${_pos!.accuracy.round()} m'
                    : (_locError ?? 'Mengambil lokasi…'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (_pos == null && _locError == null)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else if (_locError != null)
              TextButton(onPressed: _locate, child: const Text('Ulangi')),
          ]),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: isIn ? 'Kirim absen masuk' : 'Kirim absen pulang',
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _pos == null ? null : _submit,
        ),
        const SizedBox(height: 6),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
      ]),
    );
  }
}
