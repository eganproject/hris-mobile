import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

final _scheduleProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, from) async {
  final start = DateTime.parse(from);
  final res = await ref.read(t2ApiProvider).get('schedule', query: {'from': from, 'to': ymd(start.add(const Duration(days: 6)))});
  return asMap(res['data']);
});

Color modeColor(String? mode) => switch (mode) {
      'wfh' => const Color(0xFF8B5CF6),
      'leave' => const Color(0xFF10B981),
      'off' => const Color(0xFFC3C9D6),
      'none' => Colors.transparent,
      _ => T2Colors.orange,
    };

/// Jadwal saya: strip minggu, banner konfirmasi jadwal terbit, dan kartu per hari.
class JadwalPage extends ConsumerStatefulWidget {
  const JadwalPage({super.key});

  @override
  ConsumerState<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends ConsumerState<JadwalPage> {
  DateTime _week = _monday(DateTime.now());

  Future<void> _confirm(String weekStart) async {
    try {
      final res = await ref.read(t2ApiProvider).post('schedule/confirm', data: {'week_start': weekStart});
      ref.invalidate(_scheduleProvider);
      if (mounted) showSnack(context, (res['message'] ?? 'Terkonfirmasi.') as String);
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = ymd(_week);
    final schedule = ref.watch(_scheduleProvider(key));
    final thisWeek = _monday(DateTime.now());
    final label = _week == thisWeek
        ? 'Minggu ini'
        : _week == thisWeek.add(const Duration(days: 7))
            ? 'Minggu depan'
            : '${_week.day} ${monthShort(_week)}';

    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: AsyncBody<Map<String, dynamic>>(
          value: schedule,
          onRefresh: () async => ref.invalidate(_scheduleProvider(key)),
          builder: (data) {
            final days = asList(data['days']);
            final pending = asList(data['pending_confirmations']);
            final today = ymd(DateTime.now());

            return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
              BackHeader(
                title: 'Jadwal saya',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(onPressed: () => setState(() => _week = _week.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
                  Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => setState(() => _week = _week.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
                ]),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  for (final d in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _DayPill(day: d, isToday: d['date'] == today),
                      ),
                    ),
                ]),
              ),
              for (final p in pending) ...[
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Color(0xFFB45309)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Jadwal ${rangeLabel(p['week_start'], p['week_end'])} sudah terbit',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF78350F))),
                        const Text('Cek dan konfirmasi ya', style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E))),
                      ]),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), shape: const StadiumBorder()),
                      onPressed: () => _confirm(p['week_start'] as String),
                      child: const Text('Konfirmasi'),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              for (final d in days)
                Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: _DayCard(day: d, today: today)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder(), foregroundColor: T2Colors.orangeText),
                  onPressed: () => context.push('/pengajuan/tukar'),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Ajukan tukar jadwal'),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.isToday});
  final Map<String, dynamic> day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(day['date'] as String);
    final fg = isToday ? Colors.white : (day['is_holiday'] == true || d.weekday == 7 ? const Color(0xFFC2410C) : T2Colors.ink);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        gradient: isToday ? T2Colors.gradient : null,
        color: isToday ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x14111C45), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(dayShort(d), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isToday ? Colors.white70 : T2Colors.muted)),
        Text('${d.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: fg)),
        Container(width: 5, height: 5, decoration: BoxDecoration(color: isToday ? Colors.white : modeColor(day['mode'] as String?), shape: BoxShape.circle)),
      ]),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.today});
  final Map<String, dynamic> day;
  final String today;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(day['date'] as String);
    final tomorrow = ymd(DateTime.now().add(const Duration(days: 1)));
    final prefix = day['date'] == today ? 'Hari ini · ' : day['date'] == tomorrow ? 'Besok · ' : '';
    final shift = day['shift'] as Map?;
    final mode = day['mode'] as String?;
    final chip = switch (mode) {
      'wfh' => ('WFH', 'accent'),
      'leave' => ('Cuti', 'success'),
      'off' => ('Libur', null),
      'none' => ('Belum dijadwalkan', 'warning'),
      'trip' => ('Dinas luar', 'info'),
      _ => (day['date'] == today ? 'Bekerja' : 'Kantor', 'warning'),
    };
    final leaveName = mode == 'leave' && day['leave'] is Map ? (day['leave'] as Map)['name'] : null;
    final detail = shift != null
        ? '${shift['start_time']} – ${shift['end_time']}${day['location'] != null ? ' · ${day['location']}' : ''}'
        : (day['holiday_name'] ?? leaveName ?? '') as String;

    return T2Card(
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, decoration: BoxDecoration(color: modeColor(mode) == Colors.transparent ? T2Colors.line : modeColor(mode), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$prefix${dayShort(d)} ${d.day} ${monthShort(d)}', style: const TextStyle(fontSize: 12.5, color: T2Colors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(day['label'] as String? ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (detail.isNotEmpty) Text(detail, style: const TextStyle(fontSize: 13, color: T2Colors.muted)),
              if (day['pending_leave'] != null)
                Text('Menunggu persetujuan: ${day['pending_leave']['name']}', style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
            ]),
          ),
          Center(child: StatusChip(chip.$1, tone: chip.$2)),
        ]),
      ),
    );
  }
}
