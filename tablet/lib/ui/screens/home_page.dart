import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/pin.dart';
import '../../core/predict.dart';
import '../../core/tablet_controller.dart';
import '../../face/camera_service.dart';
import '../../face/face_engine.dart';
import '../../face/frame.dart';
import '../../face/matcher.dart';
import '../theme.dart';
import '../widgets/camera_panel.dart';
import '../widgets/common.dart';
import 'hr_menu_page.dart';

enum _Phase { idle, scanning, result, unknown, pin, confirm }

/// Wajah/PIN sudah cocok tetapi pilihan Masuk/Pulang janggal: menunggu jawaban.
class _Pending {
  _Pending({required this.employee, required this.frame, required this.method, required this.at, required this.check, required this.chosen, this.score, this.margin, this.liveness});
  final Employee employee;
  final FrameData? frame;
  final String method;
  final DateTime at;
  final ChoiceCheck check;
  final String chosen;
  final double? score;
  final double? margin;
  final double? liveness;
}

class _Result {
  _Result({
    required this.employee,
    required this.type,
    required this.at,
    required this.method,
    this.ignored = false,
    this.since,
    this.record,
  });
  final Employee employee;
  final String type;
  final DateTime at;
  final String method;
  final bool ignored;
  final DateTime? since;
  final PendingRecord? record;
}

/// Layar utama tablet: pilih Absen Masuk / Absen Pulang di atas (terpilih
/// otomatis sesuai jam), lalu hadapkan wajah.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.tablet, required this.camera, required this.engine});
  final TabletController tablet;
  final CameraService camera;
  final FaceEngine engine;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _Phase _phase = _Phase.idle;
  FaceIssue _issue = FaceIssue.noFace;
  bool _spoof = false;
  DateTime? _unknownSince;
  DateTime? _lastFaceAt;
  _Result? _result;
  int _countdown = 0;
  Timer? _timer;
  Timer? _idleTimer;
  FrameData? _lastFrame;
  final Map<int, DateTime> _cooldown = {};
  late ConsecutiveTracker _tracker;

  // Tombol Absen Masuk / Absen Pulang. null = ikut jam (pilihan bawaan).
  String? _manualChoice;
  Timer? _choiceTimer;
  _Pending? _pending;

  // NIK + PIN
  String _pinQuery = '';
  Employee? _pinEmployee;
  String _pin = '';
  String? _pinError;
  int _pinFails = 0;
  DateTime? _pinLockedUntil;

  TabletSettings get _settings => widget.tablet.data?.settings ?? const TabletSettings();

  @override
  void initState() {
    super.initState();
    _tracker = ConsecutiveTracker(_settings.consecutiveFrames);
    widget.camera.onFrame = _onFrame;
    widget.tablet.addListener(_onTablet);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idleTimer?.cancel();
    _choiceTimer?.cancel();
    widget.tablet.removeListener(_onTablet);
    if (widget.camera.onFrame == _onFrame) widget.camera.onFrame = null;
    super.dispose();
  }

  void _onTablet() {
    if (mounted) setState(() {});
  }

  String get _choice => _manualChoice ?? widget.tablet.defaultChoiceAt(DateTime.now());

  void _choose(String type) {
    if (_phase == _Phase.result || _phase == _Phase.confirm) return;
    setState(() => _manualChoice = type);
    // Pilihan manual kembali ke otomatis bila tidak ada yang absen dalam 30 detik,
    // supaya orang berikutnya tidak ikut mode yang salah.
    _choiceTimer?.cancel();
    _choiceTimer = Timer(const Duration(seconds: 30), _clearChoice);
  }

  void _clearChoice() {
    _choiceTimer?.cancel();
    if (!mounted) return;
    setState(() => _manualChoice = null);
  }

  void _setPhase(_Phase p) {
    if (!mounted) return;
    setState(() => _phase = p);
    _idleTimer?.cancel();
    if (p == _Phase.unknown || p == _Phase.pin || p == _Phase.confirm) {
      // Kembali ke layar awal bila ditinggal. Pertanyaan yang tidak dijawab = tidak dicatat.
      _idleTimer = Timer(Duration(seconds: p == _Phase.pin ? 45 : 15), p == _Phase.confirm ? _cancelPending : _reset);
    }
  }

  void _reset() {
    _tracker.reset();
    _unknownSince = null;
    _pinEmployee = null;
    _pin = '';
    _pinQuery = '';
    _pinError = null;
    _spoof = false;
    _setPhase(_Phase.idle);
  }

  Future<void> _onFrame(FrameData frame) async {
    _lastFrame = frame;
    if (_phase == _Phase.result || _phase == _Phase.pin || _phase == _Phase.confirm) return;

    final data = widget.tablet.data;
    if (data == null) return;
    final s = data.settings;
    if (_tracker.required != s.consecutiveFrames) _tracker = ConsecutiveTracker(s.consecutiveFrames);

    final obs = await widget.engine.analyze(frame, liveness: s.livenessEnabled);
    if (!mounted || _phase == _Phase.result || _phase == _Phase.pin || _phase == _Phase.confirm) return;
    final now = DateTime.now();

    if (obs.issue == FaceIssue.noFace) {
      _tracker.reset();
      _unknownSince = null;
      if (_phase == _Phase.scanning && (_lastFaceAt == null || now.difference(_lastFaceAt!) > const Duration(milliseconds: 1200))) {
        _spoof = false;
        _setPhase(_Phase.idle);
      }
      return;
    }

    _lastFaceAt = now;
    if (_phase == _Phase.idle) _setPhase(_Phase.scanning);

    if (!obs.usable || !FaceEngine.frontal(obs)) {
      _tracker.reset();
      setState(() {
        _issue = obs.usable ? FaceIssue.notFrontal : obs.issue;
      });
      return;
    }

    final live = obs.liveness;
    if (s.livenessEnabled && live != null && live < s.livenessPass) {
      _tracker.reset();
      _unknownSince ??= now;
      setState(() {
        _issue = FaceIssue.none;
        _spoof = true;
      });
      if (now.difference(_unknownSince!) > unknownAfter) _setPhase(_Phase.unknown);
      return;
    }

    final match = matchFace(obs.embedding!, data.gallery, threshold: s.matchThreshold, margin: s.matchMargin);
    setState(() {
      _issue = FaceIssue.none;
      _spoof = false;
    });

    if (!match.accepted) {
      _tracker.reset();
      _unknownSince ??= now;
      if (now.difference(_unknownSince!) > unknownAfter) _setPhase(_Phase.unknown);
      return;
    }

    _unknownSince = null;
    final id = match.employeeId!;
    final until = _cooldown[id];
    if (until != null && now.isBefore(until)) return;

    if (_tracker.add(id, score: match.score, margin: match.margin, liveness: live)) {
      final employee = data.byId[id];
      if (employee == null) return;
      await _commit(
        employee,
        frame,
        method: 'face',
        score: _tracker.meanScore,
        margin: _tracker.meanMargin,
        liveness: s.livenessEnabled ? _tracker.meanLiveness : null,
      );
      _tracker.reset();
    }
  }

  Future<void> _commit(Employee employee, FrameData? frame, {required String method, double? score, double? margin, double? liveness}) async {
    final now = DateTime.now();
    final chosen = _choice;
    final check = widget.tablet.checkChoice(employee, now, chosen);

    switch (check.outcome) {
      case ChoiceOutcome.ignored:
        _showResult(_Result(employee: employee, type: check.type, at: now, method: method, ignored: true, since: check.since), seconds: 3);
        _cooldown[employee.id] = now.add(const Duration(seconds: 10));
        return;
      case ChoiceOutcome.alreadyIn:
      case ChoiceOutcome.notIn:
        _pending = _Pending(employee: employee, frame: frame, method: method, at: now, check: check, chosen: chosen, score: score, margin: margin, liveness: liveness);
        _setPhase(_Phase.confirm);
        return;
      case ChoiceOutcome.record:
        await _record(employee, frame, method: method, at: now, type: check.type, since: check.since, score: score, margin: margin, liveness: liveness);
    }
  }

  /// Jawaban pertanyaan: catat sebagai [type] (tanpa bertanya lagi).
  Future<void> _answer(String type) async {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    final since = type == 'out' ? p.check.since : null;
    await _record(p.employee, p.frame, method: p.method, at: p.at, type: type, since: since, score: p.score, margin: p.margin, liveness: p.liveness);
  }

  void _cancelPending() {
    final p = _pending;
    _pending = null;
    if (p != null) _cooldown[p.employee.id] = DateTime.now().add(const Duration(seconds: 6));
    _clearChoice();
    _reset();
  }

  Future<void> _record(Employee employee, FrameData? frame,
      {required String method, required DateTime at, required String type, DateTime? since, double? score, double? margin, double? liveness}) async {
    final uuid = const Uuid().v4();
    String? photo;
    if (frame != null) {
      try {
        final jpeg = await compute(encodeFrameJpeg, frame);
        photo = await widget.tablet.savePhoto(jpeg, uuid);
      } catch (e) {
        debugPrint('foto bukti gagal: $e');
      }
    }

    final record = PendingRecord(
      uuid: uuid,
      employeeId: employee.id,
      employeeName: employee.name,
      capturedAt: at,
      method: method,
      predictedType: type,
      requestedType: type,
      matchScore: score,
      matchMargin: margin,
      livenessChecked: liveness != null,
      livenessScore: liveness,
      photoPath: photo,
    );

    _showResult(_Result(employee: employee, type: type, at: at, method: method, since: since, record: record), seconds: resultSeconds);
  }

  void _showResult(_Result r, {required int seconds}) {
    _timer?.cancel();
    setState(() {
      _result = r;
      _countdown = seconds;
    });
    _setPhase(_Phase.result);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_countdown <= 1) {
        t.cancel();
        _finishResult(notMe: false);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  /// Layar hasil selesai: absen dikirim (atau dibatalkan lewat "Bukan saya").
  Future<void> _finishResult({required bool notMe}) async {
    _timer?.cancel();
    final r = _result;
    if (r == null) return _reset();
    final record = r.record;
    if (record != null) {
      final toSave = notMe
          ? PendingRecord(
              uuid: record.uuid,
              employeeId: record.employeeId,
              employeeName: record.employeeName,
              capturedAt: record.capturedAt,
              method: record.method,
              predictedType: record.predictedType,
              requestedType: record.requestedType,
              matchScore: record.matchScore,
              matchMargin: record.matchMargin,
              livenessChecked: record.livenessChecked,
              livenessScore: record.livenessScore,
              photoPath: record.photoPath,
              notMe: true,
            )
          : record;
      await widget.tablet.record(toSave, employee: r.employee);
    }
    // Orang yang sama masih di depan kamera: jangan langsung dipindai ulang.
    _cooldown[r.employee.id] = DateTime.now().add(Duration(seconds: notMe ? 6 : 12));
    _result = null;
    _clearChoice();
    _reset();
  }

  void _openPin() {
    if (!_settings.pinEnabled) return;
    _pinEmployee = null;
    _pin = '';
    _pinQuery = '';
    _pinError = null;
    _setPhase(_Phase.pin);
  }

  Future<void> _submitPin() async {
    final e = _pinEmployee;
    if (e == null) return;
    final locked = _pinLockedUntil;
    if (locked != null && DateTime.now().isBefore(locked)) {
      setState(() => _pinError = 'Terlalu banyak PIN salah. Coba lagi pukul ${hm(locked)}.');
      return;
    }
    if (e.pinHash == null) {
      setState(() => _pinError = 'PIN untuk ${e.name} belum diatur HR.');
      return;
    }
    final ok = await compute((List<String?> a) => verifyPin(a[0]!, a[1]), [_pin, e.pinHash]);
    if (!mounted) return;
    if (!ok) {
      _pinFails++;
      if (_pinFails >= 5) {
        _pinFails = 0;
        _pinLockedUntil = DateTime.now().add(const Duration(minutes: 1));
      }
      setState(() {
        _pin = '';
        _pinError = 'PIN salah.';
      });
      return;
    }
    _pinFails = 0;
    await _commit(e, _lastFrame, method: 'pin');
  }

  Future<void> _openHr() async {
    widget.camera.onFrame = null;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HrMenuPage(tablet: widget.tablet, camera: widget.camera, engine: widget.engine)));
    if (!mounted) return;
    widget.camera.onFrame = _onFrame;
    _reset();
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = widget.tablet.data;
    return Scaffold(
      body: DottedBackground(
        child: Column(children: [
          TabletHeader(tablet: widget.tablet, onLock: _phase == _Phase.result || _phase == _Phase.confirm ? null : _openHr),
          Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 0), child: _choiceBar()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 58, child: _cameraPanel(data)),
                const SizedBox(width: 24),
                Expanded(flex: 42, child: _side(data)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cameraPanel(SyncData? data) {
    final s = _settings;
    switch (_phase) {
      case _Phase.idle:
        return CameraPanel(
          camera: widget.camera,
          bracket: C.yellow,
          topLeft: const GlassPill('Kamera aktif', dot: C.red),
          topRight: s.livenessEnabled ? const GlassPill('Cek wajah asli aktif', icon: Icons.shield_outlined) : null,
          bottom: HintCard(
            title: data == null ? 'Menyiapkan data karyawan…' : 'Hadapkan wajah untuk ${_choice == 'in' ? 'Absen Masuk' : 'Absen Pulang'}',
            subtitle: data == null ? 'Butuh internet untuk sinkron pertama' : 'Salah pilih? Ketuk tombol di atas',
          ),
        );
      case _Phase.scanning:
        return CameraPanel(
          camera: widget.camera,
          bracket: _spoof ? C.red : C.yellow,
          topLeft: GlassPill(_spoof ? 'Wajah asli belum terdeteksi' : 'Wajah terdeteksi', solid: _spoof ? C.red : C.yellow, solidText: _spoof ? Colors.white : C.navy),
          topRight: GlassPill(_issue == FaceIssue.none ? 'Tahan sebentar…' : faceIssueText(_issue)),
        );
      case _Phase.result:
        final r = _result;
        return CameraPanel(
          camera: widget.camera,
          bracket: r?.ignored == true ? C.blue : C.green,
          topLeft: GlassPill(r?.method == 'pin' ? 'NIK + PIN' : 'Wajah cocok', icon: Icons.check, solid: C.green),
          topRight: GlassPill(r?.ignored == true ? 'Sudah tercatat' : (widget.tablet.online ? 'Foto bukti tersimpan' : 'Tersimpan di tablet')),
        );
      case _Phase.unknown:
        return CameraPanel(
          camera: widget.camera,
          bracket: C.red,
          topLeft: GlassPill(_spoof ? 'Wajah asli belum terdeteksi' : 'Tidak ada data wajah yang cocok', dot: C.red),
        );
      case _Phase.pin:
        return CameraPanel(camera: widget.camera, bracket: C.yellow, topLeft: const GlassPill('Absen pakai NIK + PIN', icon: Icons.pin_outlined), topRight: const GlassPill('Tetap difoto dan ditandai untuk HR'));
      case _Phase.confirm:
        final p = _pending;
        return CameraPanel(
          camera: widget.camera,
          bracket: C.yellow,
          topLeft: GlassPill(p == null ? 'Wajah cocok' : (p.method == 'pin' ? 'NIK + PIN' : 'Wajah cocok: ${p.employee.name}'), icon: Icons.check, solid: C.green),
          topRight: const GlassPill('Belum dicatat'),
        );
    }
  }

  Widget _side(SyncData? data) => switch (_phase) {
        _Phase.idle => _idleSide(data),
        _Phase.scanning => _scanningSide(data),
        _Phase.result => _resultSide(),
        _Phase.unknown => _unknownSide(),
        _Phase.pin => _pinSide(data),
        _Phase.confirm => _confirmSide(),
      };

  Widget _choiceBar() => LiveClock(
        builder: (context, _) {
          final chosen = _choice;
          final locked = _phase == _Phase.result || _phase == _Phase.confirm;
          return Row(children: [
            Expanded(child: _choiceButton('in', 'Absen Masuk', 'Datang kerja', Icons.login_rounded, C.greenText, chosen == 'in', locked)),
            const SizedBox(width: 16),
            Expanded(child: _choiceButton('out', 'Absen Pulang', 'Selesai kerja', Icons.logout_rounded, C.navy, chosen == 'out', locked)),
          ]);
        },
      );

  Widget _choiceButton(String type, String label, String sub, IconData icon, Color color, bool selected, bool locked) {
    final fg = selected ? Colors.white : const Color(0xFF344054);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? color : const Color(0xFFD0D5DD), width: 2),
        ),
        elevation: selected ? 6 : 0,
        shadowColor: color.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: locked ? null : () => _choose(type),
          child: SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(children: [
                Icon(icon, size: 28, color: fg),
                const SizedBox(width: 16),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: fg)),
                  Text(sub, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? const Color(0xCCFFFFFF) : C.muted)),
                ]),
                const Spacer(),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : null,
                    border: selected ? null : Border.all(color: const Color(0xFFD0D5DD), width: 2),
                  ),
                  child: selected ? Icon(Icons.check, size: 18, color: color) : null,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmSide() {
    final p = _pending;
    if (p == null) return const SizedBox.shrink();
    final e = p.employee;
    final alreadyIn = p.check.outcome == ChoiceOutcome.alreadyIn;
    final title = alreadyIn ? 'Sudah absen masuk hari ini' : 'Belum absen masuk hari ini';
    final body = alreadyIn
        ? 'Kamu memilih Absen Masuk, padahal sudah tercatat masuk pukul ${hm(p.check.since ?? p.at)}. Mau dicatat sebagai absen pulang?'
        : 'Kamu memilih Absen Pulang, padahal belum ada absen masuk hari ini. Mau dicatat sebagai apa?';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardBox(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 84,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            decoration: const BoxDecoration(color: C.yellowSoft, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: C.yellow, shape: BoxShape.circle),
                child: const Text('!', style: TextStyle(color: C.navy, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Color(0xFF93370D), fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(e.initials, size: 76, bg: C.navy, fg: C.yellow, border: true),
                const SizedBox(height: 12),
                const Text('Halo,', style: TextStyle(fontSize: 15, color: C.muted)),
                Text(e.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 14),
                Text(body, style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF344054))),
                const SizedBox(height: 18),
                if (alreadyIn)
                  Row(children: [
                    Expanded(child: FilledButton(onPressed: () => _answer('out'), style: FilledButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: C.navy), child: const Text('Ya, catat pulang'))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton(onPressed: _cancelPending, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)), child: const Text('Batal'))),
                  ])
                else ...[
                  Row(children: [
                    Expanded(child: FilledButton(onPressed: () => _answer('in'), style: FilledButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: C.greenText), child: const Text('Catat masuk'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => _answer('out'), style: FilledButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: C.navy), child: const Text('Tetap catat pulang'))),
                  ]),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: _cancelPending, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('Batal')),
                ],
              ]),
            ),
          ),
        ]),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
        child: const Text('Tidak ada yang dicatat kalau tidak dipilih.', style: TextStyle(fontSize: 13, color: C.muted)),
      ),
    ]);
  }

  Widget _idleSide(SyncData? data) {
    final recent = widget.tablet.recent();
    final total = data?.total ?? 0;
    final present = widget.tablet.presentCount;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LiveClock(
        builder: (context, now) => Container(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
          decoration: BoxDecoration(
            color: C.navy,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x8016255A), blurRadius: 28, offset: Offset(0, 12), spreadRadius: -10)],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              right: -88,
              top: -88,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.yellow.withValues(alpha: 0.35), width: 18)),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.wb_sunny_outlined, color: C.yellow, size: 18),
                const SizedBox(width: 8),
                Text(greeting(now), style: const TextStyle(color: C.yellow, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(hm(now),
                    style: const TextStyle(color: Colors.white, fontSize: 88, fontWeight: FontWeight.w800, letterSpacing: -4, height: 1, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 6),
                const Text('WIB', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 26)),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (data != null) _chip('${data.enrolledCount} wajah terdaftar', const Color(0x1AFFFFFF), Colors.white),
                if (widget.tablet.queueCount > 0) _chip('${widget.tablet.queueCount} absen menunggu dikirim', C.yellow, C.navy),
              ]),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: CardBox(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
              child: Row(children: [
                const Text('Baru saja absen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (total > 0)
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '$present', style: const TextStyle(fontWeight: FontWeight.w700, color: C.text)),
                    TextSpan(text: ' dari $total hadir'),
                  ]), style: const TextStyle(fontSize: 13, color: C.muted)),
              ]),
            ),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: (present / total).clamp(0, 1), minHeight: 6, color: C.green, backgroundColor: const Color(0xFFF2F4F7)),
                ),
              ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const Padding(padding: EdgeInsets.all(22), child: Text('Belum ada absen hari ini.', style: TextStyle(color: C.muted)))
            else
              for (final r in recent)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                  child: Row(children: [
                    Avatar(r.initials.isEmpty ? '•' : r.initials),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    _chip('${r.type == 'in' ? 'Masuk' : 'Pulang'} ${hm(r.at)}', r.type == 'in' ? C.greenSoft : C.blueSoft, r.type == 'in' ? C.greenText : C.blueText, small: true),
                  ]),
                ),
          ]),
        ),
      ),
    ]);
  }

  Widget _chip(String text, Color bg, Color fg, {bool small = false}) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontSize: small ? 12 : 13, fontWeight: FontWeight.w700)),
      );

  Widget _check(String title, String subtitle, {required bool? state}) {
    // state: true = lolos, false = gagal, null = sedang
    final (bg, border, icon) = switch (state) {
      true => (C.surface2, null, Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check, color: C.green, size: 22),
          )),
      false => (C.redSoft, const Color(0xFFFDA29B), Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.close, color: C.red, size: 22),
          )),
      null => (C.yellowSoft, const Color(0xFFFCE3A1), Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 3, color: C.yellowText)),
          )),
    };
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: border == null ? null : Border.all(color: border)),
      child: Row(children: [
        icon,
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _scanningSide(SyncData? data) {
    final s = _settings;
    final clear = _issue == FaceIssue.none;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 6, color: C.yellow, backgroundColor: Color(0xFFF2F4F7))),
            SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Memindai wajah', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.navy)),
              Text('Biasanya kurang dari 1 detik', style: TextStyle(fontSize: 14, color: C.muted)),
            ]),
          ]),
          const SizedBox(height: 22),
          _check(clear ? 'Wajah terlihat jelas' : faceIssueText(_issue), 'Terang, menghadap depan, jarak normal', state: clear ? true : null),
          if (s.livenessEnabled) _check(_spoof ? 'Gunakan wajah asli' : 'Wajah asli', 'Bukan foto atau layar', state: !clear ? null : !_spoof),
          _check('Mencocokkan', 'Dengan ${data?.enrolledCount ?? 0} data wajah kantor ini', state: null),
        ]),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          Icon(Icons.shield_outlined, color: C.yellow),
          SizedBox(width: 14),
          Expanded(child: Text('Wajah dicocokkan di dalam tablet. Foto saat absen hanya bisa dilihat HR.', style: TextStyle(fontSize: 13, color: Color(0xCCFFFFFF), height: 1.5))),
        ]),
      ),
    ]);
  }

  Widget _resultSide() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();
    final e = r.employee;
    final isIn = r.type == 'in';
    final offline = !widget.tablet.online;

    final String headline;
    final Color soft, strong, text;
    if (r.ignored) {
      headline = isIn ? 'Sudah absen masuk' : 'Sudah absen pulang';
      (soft, strong, text) = (C.blueSoft, C.blue, C.blueText);
    } else {
      headline = isIn ? 'Absen masuk berhasil' : 'Absen pulang berhasil';
      (soft, strong, text) = isIn ? (C.greenSoft, C.green, C.greenText) : (C.blueSoft, C.blue, C.blueText);
    }

    final chips = <Widget>[];
    if (r.ignored) {
      chips.add(_chip('Tidak dicatat ulang', C.indigoSoft, C.indigoText, small: true));
    } else if (isIn) {
      final p = punctualityLabel(e, r.at);
      if (p != null) chips.add(_chip(p, p == 'Tepat waktu' ? C.greenSoft : C.yellowSoft, p == 'Tepat waktu' ? C.greenText : C.yellowText, small: true));
      if (e.schedule != null) chips.add(_chip('Jadwal ${e.schedule!.start}–${e.schedule!.end}', C.indigoSoft, C.indigoText, small: true));
    } else if (r.since != null) {
      chips.add(_chip(durationLabel(r.at.difference(r.since!)), C.blueSoft, C.blueText, small: true));
      chips.add(_chip('Masuk ${hm(r.since!)}', C.indigoSoft, C.indigoText, small: true));
    }
    if (offline && !r.ignored) chips.add(_chip('Menunggu dikirim', C.yellowSoft, C.yellowText, small: true));
    if (r.method == 'pin') chips.add(_chip('Ditandai untuk HR', C.yellowSoft, C.yellowText, small: true));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (offline && !r.ignored)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.yellowSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFCE3A1))),
          child: const Text('Internet terputus. Absen disimpan di tablet dan dikirim otomatis saat tersambung.', style: TextStyle(fontSize: 13, color: C.yellowText, fontWeight: FontWeight.w600)),
        ),
      CardBox(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 84,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            decoration: BoxDecoration(color: soft, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(color: strong, shape: BoxShape.circle), child: const Icon(Icons.check, size: 15, color: Colors.white)),
              const SizedBox(width: 8),
              Text(headline, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(e.initials, size: 76, bg: C.navy, fg: C.yellow, border: true),
                const SizedBox(height: 12),
                Text(r.ignored ? 'Halo,' : (isIn ? '${greeting(r.at)},' : 'Terima kasih, hati-hati di jalan'), style: const TextStyle(fontSize: 15, color: C.muted)),
                Text(e.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text([e.position, widget.tablet.data?.branchName].whereType<String>().where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 14, color: C.muted)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF2F4F7))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isIn ? 'JAM MASUK' : 'JAM PULANG', style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(hm(r.ignored ? (r.since ?? r.at) : r.at),
                          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: -2, height: 1, color: C.navy, fontFeatures: [FontFeature.tabularFigures()])),
                    ]),
                    const Spacer(),
                    Flexible(child: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: chips)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
        child: Row(children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: _countdown / (r.ignored ? 3 : resultSeconds), strokeWidth: 4, color: C.navy, backgroundColor: const Color(0xFFF2F4F7)),
              Text('$_countdown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.navy)),
            ]),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Kembali ke layar awal', style: TextStyle(fontSize: 13, color: C.muted))),
          if (!r.ignored)
            OutlinedButton(
              onPressed: () => _finishResult(notMe: true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 48),
                foregroundColor: C.redText,
                backgroundColor: C.redSoft,
                side: const BorderSide(color: Color(0xFFFDA29B)),
              ),
              child: const Text('Bukan saya'),
            ),
        ]),
      ),
    ]);
  }

  Widget _unknownSide() {
    final pin = _settings.pinEnabled;
    final tips = _spoof
        ? const ['Hadapkan wajah asli, bukan foto atau layar HP', 'Berdiri pada jarak normal, kepala dan bahu terlihat', 'Hindari cahaya terang dari belakang']
        : const ['Lepas masker, topi, atau kacamata hitam', 'Mundur sedikit bila terlalu dekat', 'Hindari cahaya terang dari belakang', 'Belum pernah daftar wajah? Hubungi HR'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardBox(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 64, decoration: const BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.vertical(top: Radius.circular(20)))),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 4)),
                  child: const Icon(Icons.person_off_outlined, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(_spoof ? 'Wajah asli belum terdeteksi' : 'Wajah belum dikenali', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Coba lagi dengan wajah menghadap lurus ke kamera.', style: TextStyle(fontSize: 14, color: C.muted)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final t in tips)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF98A2B3), shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t, style: const TextStyle(fontSize: 14, color: Color(0xFF344054)))),
                        ]),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
      const Spacer(),
      FilledButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
      if (pin) ...[
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _openPin, child: const Text('Absen pakai NIK + PIN')),
        const SizedBox(height: 8),
        const Text('Absen pakai PIN tetap difoto dan ditandai untuk HR', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted)),
      ],
    ]);
  }

  Widget _pinSide(SyncData? data) {
    final e = _pinEmployee;
    if (e == null) {
      final q = _pinQuery.trim().toLowerCase();
      final list = (data?.employees ?? const <Employee>[])
          .where((x) => q.length >= 2 && (x.name.toLowerCase().contains(q) || x.nik.toLowerCase().contains(q)))
          .take(6)
          .toList();
      return CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Absen pakai NIK + PIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.navy))),
            TextButton(onPressed: _reset, child: const Text('Batal')),
          ]),
          const SizedBox(height: 4),
          const Text('Ketik nama atau NIK, lalu pilih namamu.', style: TextStyle(color: C.muted)),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nama atau NIK'),
            onChanged: (v) => setState(() => _pinQuery = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(children: [
              for (final x in list)
                ListTile(
                  leading: Avatar(x.initials),
                  title: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([x.nik, x.position].whereType<String>().join(' · ')),
                  onTap: () => setState(() {
                    _pinEmployee = x;
                    _pin = '';
                    _pinError = null;
                    FocusScope.of(context).unfocus();
                  }),
                ),
            ]),
          ),
        ]),
      );
    }
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(e.initials, size: 48, bg: C.navy, fg: C.yellow),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(e.nik, style: const TextStyle(color: C.muted)),
            ]),
          ),
          TextButton(onPressed: () => setState(() => _pinEmployee = null), child: const Text('Ganti')),
        ]),
        const SizedBox(height: 16),
        const Text('Masukkan PIN absen (6 angka)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        PinPad(length: 6, value: _pin, onChanged: (v) => setState(() => _pin = v), onSubmit: _submitPin, submitLabel: 'Absen'),
        if (_pinError != null) ...[
          const SizedBox(height: 10),
          Text(_pinError!, textAlign: TextAlign.center, style: const TextStyle(color: C.redText, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}
