import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../core/widgets/ui.dart';
import '../absen/attendance_models.dart';
import '../absen/attendance_repository.dart';
import '../absen/offline_queue.dart';

/// Beranda: jam, jadwal hari ini, lokasi kantor, tombol bulat Masuk/Pulang,
/// ringkasan jam masuk & pulang. Saat sesi terbuka tampil "Sedang bekerja".
class BerandaPage extends ConsumerStatefulWidget {
  const BerandaPage({super.key});

  @override
  ConsumerState<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends ConsumerState<BerandaPage> with WidgetsBindingObserver {
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(attendanceStatusProvider);
      ref.read(offlineQueueProvider.notifier).flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final status = ref.watch(attendanceStatusProvider);
    final queue = ref.watch(offlineQueueProvider);

    // Absen yang masih antre menentukan tombol berikutnya walau server belum tahu.
    final pending = queue.latest;
    final data = status.value;
    final working = pending != null ? pending.type == 'in' : (data?.sessionOpen ?? false);
    final clockInAt = pending?.type == 'in' ? pending!.capturedAt : data?.clockInAt;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(attendanceStatusProvider);
          await ref.read(offlineQueueProvider.notifier).flush();
          await ref.read(attendanceStatusProvider.future).catchError((_) => data!);
        },
        child: Stack(children: [
          GradientHeaderBackground(height: working ? 250 : 330),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _header(user?.initials ?? '', user?.firstName ?? ''),
                if (working)
                  _workingHeader(data)
                else
                  _clockHeader(data),
                if (queue.items.isNotEmpty) _queueBanner(queue),
                if (status.hasError && data == null) _errorCard(status.error!),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: working ? _workingBody(data, clockInAt) : _idleBody(data),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(String initials, String firstName) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Fmt.greeting(_now), style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13)),
              Text('Halo, $firstName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          Semantics(
            label: 'Notifikasi',
            button: true,
            child: InkResponse(
              onTap: () => context.push('/notifikasi'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ),
          ),
        ]),
      );

  Widget _clockHeader(AttendanceStatusDto? data) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(children: [
          Text(Fmt.longDate(_now), style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13, fontWeight: FontWeight.w600)),
          Text(Fmt.time(_now),
              style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: -2, height: 1.05)),
          const SizedBox(height: 8),
          StatusPill(
            label: data == null ? 'Memuat jadwal…' : '${data.isRemote ? '${data.modeLabel} · ' : ''}${data.shiftLabel}',
            tone: PillTone.onPrimary,
            icon: Icons.schedule,
          ),
        ]),
      );

  Widget _workingHeader(AttendanceStatusDto? data) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${Fmt.shortDate(_now)}${data?.shiftName != null ? ' · ${data!.shiftName}' : ''}',
                style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Text('Sedang bekerja', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
          if (data != null)
            StatusPill(
              label: data.isRemote ? data.modeLabel : (data.location?.name ?? 'Kantor'),
              tone: PillTone.onPrimary,
              icon: Icons.place_outlined,
            ),
        ]),
      );

  Widget _idleBody(AttendanceStatusDto? data) {
    final day = data?.attendance;
    final doneToday = day?.clockIn != null && day?.clockOut != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (data != null) _locationCard(data),
      const SizedBox(height: 16),
      Center(child: _bigButton(data)),
      if (doneToday)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Absen hari ini sudah lengkap.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        ),
      const SizedBox(height: 16),
      _timesCard(day?.clockIn, day?.clockOut),
    ]);
  }

  Widget _locationCard(AttendanceStatusDto data) {
    if (data.isRemote) {
      return AppCard(
        child: Row(children: [
          _iconBox(Icons.home_work_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hari ini ${data.modeLabel}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Absen dari mana saja. Lokasi tetap dicatat, tanpa batas area.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ]),
          ),
        ]),
      );
    }
    final loc = data.location;
    final enabled = loc?.enabled ?? false;
    return AppCard(
      child: Row(children: [
        _iconBox(Icons.apartment_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(loc?.name ?? 'Lokasi kerja belum diatur', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              enabled
                  ? (loc!.hasGeofence ? 'Radius absen ${loc.radiusM} m dari titik kantor' : 'Titik kantor belum diatur HR')
                  : 'Lokasi ini belum memakai absen aplikasi. Gunakan mesin absen.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _iconBox(IconData icon) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: AppColors.primaryDark),
      );

  Widget _bigButton(AttendanceStatusDto? data) {
    final subtitle = data?.isRemote == true ? 'Selfie saja' : 'Selfie + lokasi';
    return Semantics(
      button: true,
      label: 'Absen masuk',
      child: GestureDetector(
        onTap: () => context.push('/absen/in'),
        child: Container(
          width: 188,
          height: 188,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.10),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), spreadRadius: 14)],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 152,
            height: 152,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF59E0B), AppColors.primaryDark],
              ),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 34, offset: const Offset(0, 16))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.login_rounded, color: Colors.white, size: 34),
              const SizedBox(height: 4),
              const Text('Masuk', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _workingBody(AttendanceStatusDto? data, DateTime? clockInAt) {
    final elapsed = clockInAt == null ? Duration.zero : _now.difference(clockInAt);
    final targetMinutes = _shiftMinutes(data) ?? 9 * 60;
    final progress = (elapsed.inMinutes / targetMinutes).clamp(0.0, 1.0);
    final expires = data?.expiresAt;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          SizedBox(
            width: 196,
            height: 196,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.chip,
                  color: AppColors.navy,
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Sudah bekerja', style: TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                Text(Fmt.duration(elapsed), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
                Text('dari ${(targetMinutes / 60).toStringAsFixed(targetMinutes % 60 == 0 ? 0 : 1)} jam',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Absen pulang',
            child: InkWell(
              borderRadius: BorderRadius.circular(29),
              onTap: () => context.push('/absen/out'),
              child: Ink(
                height: 58,
                decoration: BoxDecoration(
                  gradient: AppColors.navyGradient,
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: const [BoxShadow(color: Color(0x4D16255A), blurRadius: 24, offset: Offset(0, 12))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Absen Pulang', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (data?.shiftEnd != null) 'Jadwal pulang ${data!.shiftEnd}',
              if (expires != null) 'sesi berakhir ${Fmt.time(expires)}${expires.day != _now.day ? ' (${Fmt.shortDate(expires)})' : ''}',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      _timesCard(clockInAt, null),
    ]);
  }

  int? _shiftMinutes(AttendanceStatusDto? data) {
    final s = data?.shiftStart, e = data?.shiftEnd;
    if (s == null || e == null) return null;
    int m(String t) => int.parse(t.split(':')[0]) * 60 + int.parse(t.split(':')[1]);
    var diff = m(e) - m(s);
    if (diff <= 0) diff += 24 * 60;
    return diff;
  }

  Widget _timesCard(DateTime? clockIn, DateTime? clockOut) => AppCard(
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(child: _timeCell(Icons.login_rounded, 'Masuk', clockIn)),
            const VerticalDivider(width: 12, color: AppColors.line),
            Expanded(child: _timeCell(Icons.logout_rounded, 'Pulang', clockOut)),
          ]),
        ),
      );

  Widget _timeCell(IconData icon, String label, DateTime? at) {
    final has = at != null;
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: has ? AppColors.primarySoft : AppColors.chip, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 18, color: has ? AppColors.primaryDark : AppColors.faint),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
        Text(Fmt.time(at),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: has ? AppColors.ink : AppColors.faint)),
      ]),
    ]);
  }

  Widget _queueBanner(QueueState queue) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: AppCard(
          child: Row(children: [
            const Icon(Icons.cloud_upload_outlined, color: AppColors.primaryDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${queue.items.length} absen tersimpan di HP, menunggu sinyal. Terkirim otomatis.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: queue.sending ? null : () => ref.read(offlineQueueProvider.notifier).flush(),
              child: Text(queue.sending ? 'Mengirim…' : 'Kirim'),
            ),
          ]),
        ),
      );

  Widget _errorCard(Object error) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: AppCard(
          child: Row(children: [
            const Icon(Icons.wifi_off, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(apiErrorMessage(error), style: const TextStyle(fontSize: 13))),
            TextButton(onPressed: () => ref.invalidate(attendanceStatusProvider), child: const Text('Muat ulang')),
          ]),
        ),
      );
}
