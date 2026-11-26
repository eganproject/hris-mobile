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
      child: Column(
        children: [
          BackHeader(title: 'Jadwal saya'),
          SizedBox(height: 12),
          Expanded(child: JadwalView()),
        ],
      ),
    );
  }
}

/// Jadwal untuk rentang bebas (kalender bulanan). Kunci: `from|to`.
final scheduleRangeProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final [from, to] = key.split('|');
  final res = await ref.read(t2ApiProvider).get('schedule', query: {'from': from, 'to': to});
  return asMap(res['data']);
});

/// Label pendek di sel kalender + warna latar/teksnya.
({String text, Color bg, Color fg})? _cellChip(Map<String, dynamic>? day) {
  if (day == null) return null;
  final shift = day['shift'] as Map?;
  return switch (day['mode']) {
    'wfh' => (text: 'WFH', bg: AppColors.infoSoft, fg: AppColors.info),
    'leave' => (text: 'Cuti', bg: AppColors.successSoft, fg: AppColors.success),
    'trip' => (text: 'Dinas', bg: AppColors.infoSoft, fg: AppColors.info),
    'off' => (text: 'Libur', bg: AppColors.chip, fg: AppColors.muted),
    'none' => null,
    _ when day['is_holiday'] == true && shift == null => (text: 'Libur', bg: AppColors.dangerSoft, fg: AppColors.danger),
    _ when shift != null => (
      text: (shift['code'] as String?)?.isNotEmpty == true ? shift['code'] as String : (shift['start_time'] as String? ?? '•'),
      bg: AppColors.navySoft,
      fg: AppColors.navy,
    ),
    _ => null,
  };
}

/// Jadwal saya bergaya kalender: grid satu bulan (ketuk tanggal untuk
/// rinciannya), banner konfirmasi jadwal terbit, lalu agenda hari-hari ke depan.
/// Dipakai di tab Kehadiran dan layar /jadwal.
class JadwalView extends ConsumerStatefulWidget {
  const JadwalView({super.key, this.bottomPadding = 40});

  final double bottomPadding;

  @override
  ConsumerState<JadwalView> createState() => _JadwalViewState();
}

class _JadwalViewState extends ConsumerState<JadwalView> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  Future<void> _confirm(String weekStart) async {
    try {
      final res = await ref.read(t2ApiProvider).post('schedule/confirm', data: {'week_start': weekStart});
      ref.invalidate(scheduleRangeProvider);
      ref.invalidate(scheduleWeekProvider);
      if (mounted) showSnack(context, (res['message'] ?? 'Terkonfirmasi.') as String);
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    }
  }

  void _goMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final now = DateTime.now();
      _selected = _month.year == now.year && _month.month == now.month ? DateTime(now.year, now.month, now.day) : _month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gridStart = _monday(_month);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final gridEnd = _monday(lastDay).add(const Duration(days: 6));
    final key = '${ymd(gridStart)}|${ymd(gridEnd)}';
    final schedule = ref.watch(scheduleRangeProvider(key));
    final now = DateTime.now();
    final today = ymd(now);
    final isThisMonth = _month.year == now.year && _month.month == now.month;

    return AsyncBody<Map<String, dynamic>>(
      value: schedule,
      onRefresh: () async => ref.invalidate(scheduleRangeProvider(key)),
      builder: (data) {
        final days = asList(data['days']);
        final byDate = {for (final d in days) d['date'] as String: d};
        final pending = asList(data['pending_confirmations']);
        final selectedDay = byDate[ymd(_selected)];
        // Agenda: dari hari ini (atau awal bulan bila bulan lain) sampai akhir bulan.
        final agendaFrom = isThisMonth ? today : ymd(_month);
        final agenda = days
            .where((d) => (d['date'] as String).compareTo(agendaFrom) >= 0 && (d['date'] as String).compareTo(ymd(lastDay)) <= 0)
            .where((d) => d['date'] != ymd(_selected))
            .take(10)
            .toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, widget.bottomPadding),
          children: [
            MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _NavButton(Icons.chevron_left, 'Bulan sebelumnya', () => _goMonth(-1)),
                      Expanded(
                        child: Text(
                          '${monthLong(_month)} ${_month.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!isThisMonth)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => _goMonth((now.year - _month.year) * 12 + now.month - _month.month),
                            child: const Text('Hari ini'),
                          ),
                        ),
                      _NavButton(Icons.chevron_right, 'Bulan berikutnya', () => _goMonth(1)),
                    ],
                  ),
                  for (final p in pending) ...[
                    const SizedBox(height: 12),
                    _PendingBanner(p: p, onConfirm: () => _confirm(p['week_start'] as String)),
                  ],
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final (i, h) in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].indexed)
                              Expanded(
                                child: Text(
                                  h,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: i == 6 ? AppColors.danger : AppColors.muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (var w = gridStart; !w.isAfter(gridEnd); w = w.add(const Duration(days: 7)))
                          Row(
                            children: [
                              for (var i = 0; i < 7; i++)
                                Expanded(
                                  child: _Cell(
                                    date: DateTime(w.year, w.month, w.day + i),
                                    inMonth: DateTime(w.year, w.month, w.day + i).month == _month.month,
                                    day: byDate[ymd(DateTime(w.year, w.month, w.day + i))],
                                    isToday: ymd(DateTime(w.year, w.month, w.day + i)) == today,
                                    selected: ymd(DateTime(w.year, w.month, w.day + i)) == ymd(_selected),
                                    onTap: () => setState(() => _selected = DateTime(w.year, w.month, w.day + i)),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _Legend(AppColors.navy, 'Shift kantor'),
                      _Legend(AppColors.info, 'WFH / dinas'),
                      _Legend(AppColors.success, 'Cuti'),
                      _Legend(AppColors.faint, 'Libur'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AgendaLabel(
                    ymd(_selected) == today
                        ? 'HARI INI'
                        : '${dayLong(_selected).toUpperCase()}, ${_selected.day} ${monthShort(_selected).toUpperCase()}',
                  ),
                  selectedDay == null
                      ? const AppCard(
                          child: Text('Belum ada jadwal di tanggal ini.', style: TextStyle(color: AppColors.muted)),
                        )
                      : _DayCard(day: selectedDay, today: today),
                  if (agenda.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _AgendaLabel(isThisMonth ? 'MULAI HARI INI' : 'AGENDA BULAN INI'),
                    for (final d in agenda)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DayCard(day: d, today: today),
                      ),
                  ],
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/pengajuan/tukar?date=${ymd(_selected)}'),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                    label: const Text('Ajukan tukar jadwal'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.date,
    required this.inMonth,
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });
  final DateTime date;
  final bool inMonth;
  final Map<String, dynamic>? day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = _cellChip(day);
    final red = day?['is_holiday'] == true || date.weekday == 7;
    final numColor = isToday ? Colors.white : (red ? AppColors.danger : AppColors.ink);
    return Semantics(
      button: true,
      selected: selected,
      label: '${date.day} ${monthLong(date)}${chip == null ? '' : ', ${chip.text}'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: inMonth ? 1 : .38,
          child: Container(
            height: 58,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: selected && !isToday ? AppColors.accentSoft : null,
              borderRadius: BorderRadius.circular(10),
              border: selected ? Border.all(color: AppColors.accent, width: 1.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: isToday ? const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle) : null,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: numColor),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 16,
                  child: chip == null
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(maxWidth: 44),
                          decoration: BoxDecoration(color: chip.bg, borderRadius: BorderRadius.circular(5)),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              chip.text,
                              maxLines: 1,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: chip.fg),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
    ],
  );
}

class _AgendaLabel extends StatelessWidget {
  const _AgendaLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: .6),
    ),
  );
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.p, required this.onConfirm});
  final Map<String, dynamic> p;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
    decoration: BoxDecoration(
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFBE3A6)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: AppColors.accentText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jadwal ${rangeLabel(p['week_start'], p['week_end'])} sudah terbit',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const Text('Cek dan konfirmasi ya', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onConfirm,
          child: const Text('Konfirmasi', style: TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
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
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: isToday ? AppColors.navy : AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text(
                  dayShort(d).toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isToday ? AppColors.accent : AppColors.muted),
                ),
                Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isToday ? Colors.white : (red ? AppColors.danger : AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: modeColor(mode), shape: BoxShape.circle),
                    ),
                    if (modeColor(mode) != Colors.transparent) const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        day['label'] as String? ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (detail.isNotEmpty) Text(detail, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                if (day['pending_leave'] != null)
                  Text(
                    'Menunggu persetujuan: ${day['pending_leave']['name']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.accentText),
                  ),
              ],
            ),
          ),
          if (chip != null) StatusChip(chip.$1, tone: chip.$2),
        ],
      ),
    );
  }
}
