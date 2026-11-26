
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/tablet_controller.dart';
import '../../face/camera_service.dart';
import '../../face/face_engine.dart';
import '../../face/frame.dart';
import '../../face/matcher.dart';
import '../theme.dart';
import '../widgets/camera_panel.dart';
import '../widgets/common.dart';

/// HR mendaftarkan wajah karyawan: 3 foto (depan, kiri, kanan) diambil otomatis,
/// karyawan menyetujui pemakaian data wajah (UU PDP), lalu disimpan ke HRIS.
class EnrollPage extends StatefulWidget {
  const EnrollPage({super.key, required this.tablet, required this.camera, required this.engine, required this.hrPin});
  final TabletController tablet;
  final CameraService camera;
  final FaceEngine engine;
  final String hrPin;

  @override
  State<EnrollPage> createState() => _EnrollPageState();
}

class _EnrollPageState extends State<EnrollPage> {
  static const _steps = ['Depan', 'Kiri', 'Kanan'];
  static const _needFrames = 3;

  String _query = '';
  bool _onlyMissing = false;
  Employee? _selected;
  final List<Float32List> _captured = [];
  FrameData? _frontFrame;
  double? _sideSign;
  int _streak = 0;
  String _hint = 'Pilih karyawan di sebelah kiri';
  bool _consent = false;
  bool _saving = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    widget.camera.onFrame = _onFrame;
  }

  @override
  void dispose() {
    if (widget.camera.onFrame == _onFrame) widget.camera.onFrame = null;
    super.dispose();
  }

  void _select(Employee e) {
    setState(() {
      _selected = e;
      _restart();
    });
  }

  void _restart() {
    _captured.clear();
    _frontFrame = null;
    _sideSign = null;
    _streak = 0;
    _consent = false;
    _problem = null;
    _hint = 'Hadapkan wajah lurus ke kamera';
  }

  Future<void> _onFrame(FrameData frame) async {
    if (_selected == null || _captured.length >= 3 || _saving) return;
    final obs = await widget.engine.analyze(frame, liveness: false);
    if (!mounted || _selected == null || _captured.length >= 3) return;

    if (!obs.usable) {
      _streak = 0;
      setState(() => _hint = faceIssueText(obs.issue));
      return;
    }

    final step = _captured.length;
    final yaw = obs.yaw;
    bool ok;
    if (step == 0) {
      ok = yaw.abs() <= 10;
      if (!ok) _hint = 'Hadapkan wajah lurus ke kamera';
    } else if (step == 1) {
      ok = yaw.abs() >= 12 && yaw.abs() <= 40;
      if (!ok) _hint = 'Tolehkan wajah sedikit ke kiri';
    } else {
      ok = yaw.abs() >= 12 && yaw.abs() <= 40 && _sideSign != null && yaw.sign != _sideSign;
      if (!ok) _hint = 'Sekarang tolehkan sedikit ke kanan';
    }

    if (!ok) {
      _streak = 0;
      setState(() {});
      return;
    }

    _streak++;
    if (_streak < _needFrames) {
      setState(() => _hint = 'Tahan sebentar…');
      return;
    }

    _streak = 0;
    _captured.add(obs.embedding!);
    if (step == 0) _frontFrame = frame;
    if (step == 1) _sideSign = yaw.sign;
    setState(() {
      _hint = switch (_captured.length) {
        1 => 'Tolehkan wajah sedikit ke kiri',
        2 => 'Sekarang tolehkan sedikit ke kanan',
        _ => 'Selesai. Periksa lalu simpan.',
      };
      if (_captured.length == 3) _problem = _check();
    });
  }

  /// Cegah satu orang terdaftar dengan dua nama, dan foto yang tertukar orang.
  String? _check() {
    for (var i = 0; i < _captured.length; i++) {
      for (var j = i + 1; j < _captured.length; j++) {
        if (dot(_captured[i], _captured[j]) < 0.3) return 'Ketiga foto tidak tampak seperti orang yang sama. Ulangi foto.';
      }
    }
    final data = widget.tablet.data;
    if (data == null) return null;
    final others = data.gallery.where((g) => g.employeeId != _selected!.id).toList();
    final s = data.settings;
    for (final emb in _captured) {
      final m = matchFace(emb, others, threshold: s.matchThreshold, margin: 0);
      if (m.employeeId != null && m.score >= s.matchThreshold) {
        final who = data.byId[m.employeeId]?.name ?? 'karyawan lain';
        return 'Wajah ini mirip dengan data wajah $who. Pastikan orangnya benar; bila $who salah daftar, hapus wajahnya di web dulu.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final e = _selected;
    final front = _frontFrame;
    if (e == null || front == null || _captured.length < 3) return;
    setState(() => _saving = true);
    try {
      final jpeg = await compute(encodeFrameJpeg, front);
      await widget.tablet.api.enrollFace(
        hrPin: widget.hrPin,
        employeeId: e.id,
        model: faceModelName,
        embeddings: _captured.map(encodeEmbedding).toList(),
        photoJpeg: jpeg,
      );
      await widget.tablet.syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wajah ${e.name} tersimpan.')));
      setState(() {
        _selected = null;
        _restart();
        _hint = 'Pilih karyawan di sebelah kiri';
      });
    } on ApiException catch (err) {
      if (mounted) setState(() => _problem = err.isNetwork ? 'Tidak tersambung ke server. Daftar wajah butuh internet.' : err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.tablet.data;
    final all = data?.employees ?? const <Employee>[];
    final missing = all.where((e) => !e.hasFace).length;
    final q = _query.trim().toLowerCase();
    final list = all.where((e) => (!_onlyMissing || !e.hasFace) && (q.isEmpty || e.name.toLowerCase().contains(q) || e.nik.toLowerCase().contains(q))).toList();

    return Scaffold(
      body: DottedBackground(
        child: Column(children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.border))),
            child: Row(children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Daftar wajah karyawan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.navy)),
                Text('Menu HR · ${data?.branchName ?? ''}', style: const TextStyle(fontSize: 13, color: C.muted)),
              ]),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar menu HR'),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 320,
                  child: CardBox(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari karyawan'), onChanged: (v) => setState(() => _query = v)),
                      const SizedBox(height: 10),
                      Row(children: [
                        ChoiceChip(label: Text('Semua ${all.length}'), selected: !_onlyMissing, onSelected: (_) => setState(() => _onlyMissing = false)),
                        const SizedBox(width: 8),
                        ChoiceChip(label: Text('Belum daftar $missing'), selected: _onlyMissing, onSelected: (_) => setState(() => _onlyMissing = true)),
                      ]),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final e = list[i];
                            final sel = _selected?.id == e.id;
                            return Material(
                              color: sel ? C.indigoSoft : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                leading: Avatar(e.initials),
                                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(e.position ?? e.nik),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: e.hasFace ? C.greenSoft : C.yellowSoft, borderRadius: BorderRadius.circular(999)),
                                  child: Text(e.hasFace ? 'Terdaftar' : 'Belum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: e.hasFace ? C.greenText : C.yellowText)),
                                ),
                                onTap: _saving ? null : () => _select(e),
                              ),
                            );
                          },
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: CameraPanel(
                    camera: widget.camera,
                    bracket: _captured.length == 3 ? C.green : C.yellow,
                    topLeft: GlassPill(_hint, solid: C.yellow, solidText: C.navy),
                    bottom: _selected == null
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            for (var i = 0; i < 3; i++) ...[
                              GlassPill(i < _captured.length ? '${_steps[i]} ✓' : _steps[i], solid: i < _captured.length ? C.green : null),
                              if (i < 2) const SizedBox(width: 8),
                            ],
                          ]),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(width: 340, child: _infoCard()),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoCard() {
    final e = _selected;
    if (e == null) {
      return const CardBox(child: Center(child: Text('Pilih karyawan yang akan didaftarkan. Karyawan berdiri di depan tablet pada jarak normal.', textAlign: TextAlign.center, style: TextStyle(color: C.muted))));
    }
    final done = _captured.length == 3;
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Avatar(e.initials, size: 64, bg: C.navy, fg: C.yellow),
        const SizedBox(height: 12),
        Text(e.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text('NIK ${e.nik}${e.position == null ? '' : ' · ${e.position}'}', style: const TextStyle(color: C.muted)),
        if (e.hasFace) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Sudah terdaftar. Menyimpan akan mengganti data wajah lama.', style: TextStyle(fontSize: 13, color: C.yellowText))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(14)),
          child: Text('Diambil 3 foto: depan, kiri, kanan (${_captured.length}/3). Yang disimpan hanya pola angka wajah untuk dicocokkan, ditambah 1 foto depan untuk dilihat HR.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF344054), height: 1.45)),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _consent,
          onChanged: done ? (v) => setState(() => _consent = v ?? false) : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Karyawan sudah membaca dan menyetujui pemakaian data wajah untuk absensi (UU PDP).', style: TextStyle(fontSize: 13)),
        ),
        if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, style: const TextStyle(color: C.redText, fontWeight: FontWeight.w600))),
        const Spacer(),
        FilledButton(
          onPressed: done && _consent && _problem == null && !_saving ? _save : null,
          child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Text('Simpan wajah'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _saving ? null : () => setState(_restart), child: const Text('Ulangi foto')),
      ]),
    );
  }
}
