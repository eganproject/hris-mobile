import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/pin.dart';
import '../../core/tablet_controller.dart';
import '../../face/camera_service.dart';
import '../../face/face_engine.dart';
import '../../platform/lock_task.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'enroll_page.dart';

/// Menu HR di tablet, dibuka dengan PIN HR tablet (diatur di web HRIS).
class HrMenuPage extends StatefulWidget {
  const HrMenuPage({super.key, required this.tablet, required this.camera, required this.engine});
  final TabletController tablet;
  final CameraService camera;
  final FaceEngine engine;

  @override
  State<HrMenuPage> createState() => _HrMenuPageState();
}

class _HrMenuPageState extends State<HrMenuPage> {
  String _pin = '';
  String? _unlockedPin;
  String? _error;
  int _fails = 0;
  DateTime? _lockedUntil;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    LockTask.isLocked().then((v) => mounted ? setState(() => _locked = v) : null);
    widget.tablet.addListener(_changed);
  }

  @override
  void dispose() {
    widget.tablet.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final until = _lockedUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      setState(() => _error = 'Terlalu banyak PIN salah. Coba lagi pukul ${hm(until)}.');
      return;
    }
    final hash = widget.tablet.data?.hrPinHash;
    if (hash == null) {
      setState(() => _error = 'PIN HR tablet ini belum diatur. Atur di web HRIS: Absensi > Tablet Absensi Wajah > Atur PIN HR.');
      return;
    }
    final ok = await compute((List<String> a) => verifyPin(a[0], a[1]), [_pin, hash]);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _unlockedPin = _pin;
        _error = null;
        _fails = 0;
      });
    } else {
      _fails++;
      if (_fails >= 5) {
        _fails = 0;
        _lockedUntil = DateTime.now().add(const Duration(minutes: 2));
      }
      setState(() {
        _pin = '';
        _error = 'PIN HR salah.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DottedBackground(
        child: Column(children: [
          TabletHeader(tablet: widget.tablet, subtitle: 'Tablet ${widget.tablet.data?.tabletName ?? ''} · ${widget.tablet.data?.branchName ?? ''}'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 55, child: _left()),
                const SizedBox(width: 24),
                Expanded(flex: 45, child: _unlockedPin == null ? _pinCard() : _actions()),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _left() => CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MENU HR', style: TextStyle(fontSize: 13, color: C.yellowText, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Kelola tablet absensi dari sini.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: C.navy)),
          const SizedBox(height: 8),
          const Text('Masukkan PIN HR tablet. PIN diatur di web HRIS dan berbeda dengan PIN karyawan.', style: TextStyle(fontSize: 15, color: C.muted)),
          const SizedBox(height: 24),
          _menuRow(Icons.face_retouching_natural, 'Daftar wajah', 'Tambah atau perbarui'),
          _menuRow(Icons.cloud_upload_outlined, 'Antrean', 'Absen belum terkirim: ${widget.tablet.queueCount}'),
          _menuRow(Icons.settings_suggest_outlined, 'Tes perangkat', 'Kamera dan koneksi'),
          const Spacer(),
          TextButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back), label: const Text('Kembali ke layar absen')),
        ]),
      );

  Widget _menuRow(IconData icon, String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: C.indigoSoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: C.navy)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ]),
      );

  Widget _pinCard() => CardBox(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Masukkan PIN HR', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('6 angka', textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
          const SizedBox(height: 20),
          PinPad(length: 6, value: _pin, onChanged: (v) => setState(() => _pin = v), onSubmit: _submit),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: C.redText, fontWeight: FontWeight.w600)),
          ],
        ]),
      );

  Widget _actions() {
    final t = widget.tablet;
    return CardBox(
      child: ListView(children: [
        _action(Icons.face_retouching_natural, 'Daftar wajah karyawan', '${t.data?.enrolledCount ?? 0} dari ${t.data?.employees.length ?? 0} sudah terdaftar', () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => EnrollPage(tablet: t, camera: widget.camera, engine: widget.engine, hrPin: _unlockedPin!),
          ));
        }),
        _action(Icons.cloud_upload_outlined, 'Antrean absen', '${t.queueCount} belum terkirim${t.failed.isEmpty ? '' : ' · ${t.failed.length} ditolak server'}', _showQueue),
        _action(Icons.sync, 'Sinkron sekarang', t.lastSyncAt == null ? 'Belum pernah sinkron' : 'Terakhir ${hm(t.lastSyncAt!)}', () async {
          await t.syncNow();
          await t.flush();
          if (mounted) _snack(t.online ? 'Sinkron berhasil.' : (t.lastError ?? 'Tidak tersambung ke server.'));
        }),
        _action(Icons.settings_suggest_outlined, 'Tes perangkat', 'Kamera, koneksi, dan versi aplikasi', _showDeviceTest),
        _action(_locked ? Icons.lock_open : Icons.push_pin_outlined, _locked ? 'Lepas kunci layar' : 'Kunci layar (sematkan aplikasi)',
            _locked ? 'Tablet bisa dipakai untuk aplikasi lain' : 'Tombol Home dan Recent tidak bisa dipakai', () async {
          final ok = _locked ? await LockTask.stop() : await LockTask.start();
          final now = await LockTask.isLocked();
          if (!mounted) return;
          setState(() => _locked = now);
          if (!ok) _snack('Gagal mengubah kunci layar. Pastikan "Sematkan aplikasi" aktif di Setelan > Keamanan.');
        }),
        _action(Icons.logout, 'Keluarkan tablet dari HRIS', 'Butuh kode pasangan baru dari web untuk memakai lagi', _confirmUnpair, danger: true),
      ]),
    );
  }

  Widget _action(IconData icon, String title, String subtitle, VoidCallback onTap, {bool danger = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: C.surface2,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Icon(icon, color: danger ? C.redText : C.navy),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? C.redText : C.text)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      );

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _showQueue() {
    final t = widget.tablet;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Antrean absen'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: ListView(children: [
            if (t.queue.isEmpty) const ListTile(title: Text('Semua absen sudah terkirim.')),
            for (final r in t.queue)
              ListTile(
                leading: const Icon(Icons.schedule, color: C.yellowText),
                title: Text(r.employeeName),
                subtitle: Text('${r.notMe ? 'Dibatalkan ("Bukan saya")' : (r.predictedType == 'in' ? 'Masuk' : 'Pulang')} · ${hm(r.capturedAt)}${r.lastError == null ? '' : ' · ${r.lastError}'}'),
              ),
            if (t.failed.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Ditolak server', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final r in t.failed)
              ListTile(leading: const Icon(Icons.error_outline, color: C.redText), title: Text(r.employeeName), subtitle: Text('${hm(r.capturedAt)} · ${r.lastError ?? ''}')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
          FilledButton(
            onPressed: () async {
              await t.flush();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Kirim sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeviceTest() async {
    final t = widget.tablet;
    final started = DateTime.now();
    await t.syncNow();
    final ms = DateTime.now().difference(started).inMilliseconds;
    if (!mounted) return;
    final cam = widget.camera;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tes perangkat'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _testRow('Kamera depan', cam.ready ? 'Siap (${cam.controller?.value.previewSize?.width.toInt()}×${cam.controller?.value.previewSize?.height.toInt()})' : (cam.error ?? 'Belum siap'), cam.ready),
          _testRow('Server HRIS', t.online ? 'Tersambung ($ms ms)' : (t.lastError ?? 'Tidak tersambung'), t.online),
          _testRow('Data wajah', '${t.data?.enrolledCount ?? 0} karyawan terdaftar', (t.data?.enrolledCount ?? 0) > 0),
          _testRow('Cek wajah asli', (t.data?.settings.livenessEnabled ?? true) ? 'Aktif' : 'Dimatikan dari web', true),
          _testRow('Alamat server', apiBaseUrl, true),
          _testRow('Versi aplikasi', appVersion, true),
        ]),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup'))],
      ),
    );
  }

  Widget _testRow(String label, String value, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.error, color: ok ? C.green : C.red, size: 20),
          const SizedBox(width: 10),
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ]),
      );

  Future<void> _confirmUnpair() async {
    final t = widget.tablet;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluarkan tablet?'),
        content: Text(t.queueCount > 0
            ? 'Masih ada ${t.queueCount} absen yang belum terkirim dan akan hilang. Sambungkan internet dulu bila memungkinkan.'
            : 'Tablet perlu kode pasangan baru dari web HRIS untuk dipakai lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.red), onPressed: () => Navigator.of(context).pop(true), child: const Text('Keluarkan')),
        ],
      ),
    );
    if (ok == true) {
      await LockTask.stop();
      await t.unpairManually();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}
