import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

final scheduleWeekProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, from) async {
  final start = DateTime.parse(from);
  final res = await ref.read(t2ApiProvider).get('schedule', query: {'from': from, 'to': ymd(start.add(const Duration(days: 6)))});
  return asMap(res['data']);
});

Color modeColor(String? mode) => switch (mode) {
      'wfh' => AppColors.info,
      'leave' => AppColors.success,
      'off' => AppColors.inputLine,
      'none' => Colors.transparent,
      _ => AppColors.navy,
    };

/// Jadwal saya sebagai layar penuh (dari notifikasi / tautan lain).
class JadwalPage extends StatelessWidget {
  const JadwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DotScaffold(
      child: Column(children: [
        BackHeader(title: 'Jadwal saya'),
        SizedBox(height: 12),
        Expanded(child: JadwalView()),
      ]),
    );
  }
}

/// Isi jadwal per minggu: navigasi minggu, banner konfirmasi jadwal terbit,
/// kartu per hari, dan tombol tukar jadwal. Dipakai di tab Kehadiran.
class JadwalView extends ConsumerStatefulWidget {
  const JadwalView({super.key, this.bottomPadding = 40});

  final double bottomPadding;

  @override
  ConsumerState<JadwalView> createState() => _JadwalViewState();
}

class _JadwalViewState extends ConsumerState<JadwalView> {
  DateTime _week = _monday(DateTime.now());

  Future<void> _confirm(String weekStart) async {
    try {
      final res = await ref.read(t2ApiProvider).post('schedule/confirm', data: {'week_start': weekStart});
      ref.invalidate(scheduleWeekProvider);
      if (mounted) showSnack(context, (res['message'] ?? 'Terkonfirmasi.') as String);
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = ymd(_week);
    final schedule = ref.watch(scheduleWeekProvider(key));
    final thisWeek = _monday(DateTime.now());
    final end = _week.add(const Duration(days: 6));
    final prefix = _week == thisWeek
        ? 'Minggu ini · '
        : _week == thisWeek.add(const Duration(days: 7))
            ? 'Minggu depan · '
            : '';
    final range = _week.month == end.month
        ? '${_week.day}–${end.day} ${monthLong(end)}'
        : '${_week.day} ${monthShort(_week)} – ${end.day} ${monthShort(end)}';

    return AsyncBody<Map<String, dynamic>>(
      value: schedule,
      onRefresh: () async => ref.invalidate(scheduleWeekProvider(key)),
      builder: (data) {
        final days = asList(data['days']);
        final pending = asList(data['pending_confirmations']);
        final today = ymd(DateTime.now());

        return ListView(padding: EdgeInsets.fromLTRB(20, 4, 20, widget.bottomPadding), children: [
          Row(children: [
            _NavButton(Icons.chevron_left, 'Minggu sebelumnya', () => setState(() => _week = _week.subtract(const Duration(days: 7)))),
            Expanded(
              child: Text('$prefix$range',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
            _NavButton(Icons.chevron_right, 'Minggu berikutnya', () => setState(() => _week = _week.add(const Duration(days: 7)))),
          ]),
          for (final p in pending) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFBE3A6)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.accentText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Jadwal ${rangeLabel(p['week_start'], p['week_end'])} sudah terbit',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const Text('Cek dan konfirmasi ya', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ]),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirm(p['week_start'] as String),
                  child: const Text('Konfirmasi', style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (days.isEmpty) const EmptyNote('Belum ada jadwal minggu ini.', icon: Icons.event_busy_outlined),
          for (final d in days) Padding(padding: const EdgeInsets.only(bottom: 8), child: _DayCard(day: d, today: today)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => context.push('/pengajuan/tukar'),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text('Ajukan tukar jadwal'),
          ),
        ]);
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton(this.icon, this.tooltip, this.onTap);
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SquareIconButton(icon: icon, tooltip: tooltip, onTap: onTap);
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.today});
  final Map<String, dynamic> day;
  final String today;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(day['date'] as String);
    final isToday = day['date'] == today;
    final shift = day['shift'] as Map?;
    final mode = day['mode'] as String?;
    final chip = switch (mode) {
      'wfh' => ('WFH', 'info'),
      'leave' => ('Cuti', 'success'),
      'off' => ('Libur', null),
      'none' => ('Belum dijadwalkan', 'warning'),
      'trip' => ('Dinas luar', 'info'),
      _ => isToday ? ('Hari ini', 'warning') : null,
    };
    final leaveName = mode == 'leave' && day['leave'] is Map ? (day['leave'] as Map)['name'] : null;
    final detail = shift != null
        ? '${shift['start_time']} – ${shift['end_time']}${day['location'] != null ? ' · ${day['location']}' : ''}'
        : (day['holiday_name'] ?? leaveName ?? '') as String;
    final red = day['is_holiday'] == true || d.weekday == 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isToday ? AppColors.navy : AppColors.line, width: isToday ? 1.5 : 1),
      ),
      child: Row(children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isToday ? AppColors.navy : AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(dayShort(d).toUpperCase(),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isToday ? AppColors.accent : AppColors.muted)),
            Text('${d.day}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isToday ? Colors.white : (red ? AppColors.danger : AppColors.ink),
                )),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: modeColor(mode), shape: BoxShape.circle)),
              if (modeColor(mode) != Colors.transparent) const SizedBox(width: 6),
              Flexible(
                child: Text(day['label'] as String? ?? '-',
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (detail.isNotEmpty) Text(detail, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            if (day['pending_leave'] != null)
              Text('Menunggu persetujuan: ${day['pending_leave']['name']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.accentText)),
          ]),
        ),
        if (chip != null) StatusChip(chip.$1, tone: chip.$2),
      ]),
    );
  }
}
