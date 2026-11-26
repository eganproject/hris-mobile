import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/ui.dart';
import '../absen/attendance_models.dart';
import '../absen/attendance_repository.dart';
import '../jadwal/jadwal_page.dart';
import '../notifikasi/notifikasi_page.dart';
import '../pengajuan/pengajuan_providers.dart';
import '../pengajuan/pengajuan_widgets.dart';
import '../pengumuman/announcement_card.dart';
import '../pengumuman/pengumuman_page.dart';
import '../t2_common/t2_format.dart';

DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// Beranda karyawan: kehadiran hari ini (hanya dibaca; absen di tablet kantor
/// atau mesin gudang), jalan pintas pengajuan, sisa cuti, jadwal besok, dan
/// pengumuman HR terbaru.
class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final status = ref.watch(attendanceStatusProvider);
    final unread = ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;
    final now = DateTime.now();
    final e = user?.employee;

    return DotScaffold(
      child: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () async {
          ref.invalidate(attendanceStatusProvider);
          ref.invalidate(pengajuanSummaryProvider);
          ref.invalidate(announcementListProvider);
          ref.invalidate(unreadNotificationCountProvider);
          ref.invalidate(scheduleWeekProvider);
          await ref.read(attendanceStatusProvider.future).then((_) {}, onError: (_) {});
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Row(children: [
              const CompanyLogo(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Halo, ${user?.firstName ?? ''}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.2)),
                  Text(
                    [e?.jobPosition, e?.branchName].whereType<String>().join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ]),
              ),
              SquareIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifikasi',
                badge: unread > 0,
                onTap: () async {
                  await context.push('/notifikasi');
                  ref.invalidate(unreadNotificationCountProvider);
                },
              ),
            ]),
            const SizedBox(height: 18),
            if (status.hasError && !status.hasValue)
              AppCard(child: Text(apiErrorMessage(status.error!), style: const TextStyle(color: AppColors.danger)))
            else
              _TodayCard(data: status.value, now: now),
            const SizedBox(height: 22),
            const Text('Ajukan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              _Shortcut('Cuti', 'cuti', '/pengajuan/cuti?kategori=cuti'),
              const SizedBox(width: 10),
              _Shortcut('Izin/Sakit', 'izin', '/pengajuan/cuti?kategori=izin'),
              const SizedBox(width: 10),
              _Shortcut('Lembur', 'lembur', '/pengajuan/lembur'),
              const SizedBox(width: 10),
              _Shortcut('Tukar', 'tukar', '/pengajuan/tukar'),
            ]),
            const SizedBox(height: 14),
            const IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _LeaveBalanceCard()),
                SizedBox(width: 10),
                Expanded(child: _TomorrowCard()),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: Text('Pengumuman HR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => context.go('/info'),
                child: const Text('Lihat semua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
              ),
            ]),
            const SizedBox(height: 10),
            const _LatestAnnouncement(),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data, required this.now});
  final AttendanceStatusDto? data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final day = data?.attendance;
    final clockIn = day?.clockIn ?? data?.clockInAt;
    final (String, PillTone)? state = switch (day?.status) {
      _ when clockIn == null => null,
      'late' => ('Terlambat ${day!.lateMinutes} mnt', PillTone.accent),
      _ => ('Tepat waktu', PillTone.accent),
    };
    final shift = data == null
        ? 'Memuat jadwal…'
        : data!.shiftName == null
            ? (data!.isDayOff ? 'Libur' : 'Tanpa jadwal')
            : '${data!.shiftName} ${data!.shiftStart}–${data!.shiftEnd}';

    return NavyHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Fmt.longDate(now).replaceAll(RegExp(r' \d{4}$'), ''),
            style: const TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF), fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _time('Masuk', clockIn)),
          Container(width: 1, height: 44, color: Colors.white12),
          const SizedBox(width: 16),
          Expanded(child: _time('Pulang', day?.clockOut)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          StatusPill(label: shift, tone: PillTone.onPrimary, icon: Icons.schedule),
          if (state != null) StatusPill(label: state.$1, tone: state.$2),
        ]),
        const SizedBox(height: 12),
        Text(
          clockIn == null
              ? 'Absen masuk dan pulang dilakukan di tablet kantor atau mesin absen.'
              : 'Tercatat dari tablet kantor atau mesin absen. Absen pulang juga di sana.',
          style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF), height: 1.4),
        ),
      ]),
    );
  }

  Widget _time(String label, DateTime? at) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF), fontWeight: FontWeight.w500)),
        Text(Fmt.time(at),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              color: at == null ? Colors.white38 : Colors.white,
            )),
      ]);
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.label, this.category, this.route);
  final String label;
  final String category;
  final String route;

  @override
  Widget build(BuildContext context) {
    final s = categoryStyle(category);
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        radius: 14,
        onTap: () => context.push(route),
        child: Column(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(s.icon, color: s.fg, size: 20),
          ),
          const SizedBox(height: 7),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _LeaveBalanceCard extends ConsumerWidget {
  const _LeaveBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(pengajuanSummaryProvider).asData?.value;
    final balances = data?['balances'] as List? ?? const [];
    final b = balances.isEmpty ? null : Map<String, dynamic>.from(balances.first as Map);
    final quota = (b?['quota'] as num?)?.toInt();
    final remaining = (b?['remaining'] as num?)?.toInt();
    final ratio = quota == null || quota == 0 ? 0.0 : ((remaining ?? 0) / quota).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/pengajuan'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sisa cuti ${b?['year'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text.rich(TextSpan(children: [
          TextSpan(text: remaining == null ? '–' : '$remaining', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          TextSpan(text: quota == null ? '' : ' / $quota hari', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ])),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: ratio, minHeight: 6, color: AppColors.accent, backgroundColor: AppColors.chip),
        ),
      ]),
    );
  }
}

class _TomorrowCard extends ConsumerWidget {
  const _TomorrowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final week = ref.watch(scheduleWeekProvider(ymd(_monday(tomorrow)))).asData?.value;
    final days = (week?['days'] as List? ?? const []).map((d) => Map<String, dynamic>.from(d as Map));
    final day = days.where((d) => d['date'] == ymd(tomorrow)).firstOrNull;
    final shift = day?['shift'] as Map?;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/kehadiran?tab=jadwal'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Besok · ${dayLong(tomorrow)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(day?['label'] as String? ?? (week == null ? '–' : 'Belum dijadwalkan'),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(shift == null ? ' ' : '${shift['start_time']}–${shift['end_time']}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      ]),
    );
  }
}

class _LatestAnnouncement extends ConsumerWidget {
  const _LatestAnnouncement();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(announcementListProvider);
    return list.when(
      loading: () => const AppCard(child: SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => AppCard(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.muted))),
      data: (items) => items.isEmpty
          ? const AppCard(child: Text('Belum ada pengumuman.', style: TextStyle(color: AppColors.muted)))
          : AnnouncementCard(item: items.first, onReturn: () => ref.invalidate(announcementListProvider)),
    );
  }
}
