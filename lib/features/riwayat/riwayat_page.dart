import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../core/widgets/ui.dart';
import '../absen/attendance_models.dart';
import '../absen/attendance_repository.dart';

final _monthProvider = NotifierProvider<_MonthNotifier, DateTime>(_MonthNotifier.new);

class _MonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void shift(int delta) => state = DateTime(state.year, state.month + delta);
}

final _historyProvider = FutureProvider.autoDispose<HistoryMonth>((ref) {
  final month = ref.watch(_monthProvider);
  return ref.watch(attendanceRepositoryProvider).history(month);
});

/// Riwayat absensi per bulan + ringkasan + jalan pintas ke koreksi.
class RiwayatPage extends ConsumerWidget {
  const RiwayatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_monthProvider);
    final history = ref.watch(_historyProvider);
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(_historyProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Bulan sebelumnya',
                onPressed: () => ref.read(_monthProvider.notifier).shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(Fmt.monthYear(month),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Bulan berikutnya',
                onPressed: isCurrent ? null : () => ref.read(_monthProvider.notifier).shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
            const SizedBox(height: 8),
            ...history.when(
              loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
              error: (e, _) => [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(apiErrorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                ),
              ],
              data: (h) => [
                Row(children: [
                  _stat('${h.present}', 'Hadir', AppColors.success),
                  const SizedBox(width: 10),
                  _stat('${h.late}', 'Telat', AppColors.warning),
                  const SizedBox(width: 10),
                  _stat('${h.flagged}', 'Bertanda', AppColors.navy),
                ]),
                const SizedBox(height: 16),
                if (h.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada absensi bulan ini.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  ),
                for (final d in h.items) ...[_dayRow(d), const SizedBox(height: 10)],
              ],
            ),
            const SizedBox(height: 10),
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ada yang salah atau lupa absen?', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Ajukan koreksi ke atasan / HR'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/koreksi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _dayRow(AttendanceDay d) {
    final working = d.clockIn != null && d.clockOut == null;
    final tone = d.flags.isNotEmpty
        ? PillTone.warning
        : switch (d.status) {
            'present' || 'wfh' || 'business_trip' => PillTone.success,
            'late' || 'early_leave' => PillTone.warning,
            'absent' => PillTone.danger,
            _ => PillTone.neutral,
          };
    final label = working
        ? 'Bekerja'
        : d.flags.isNotEmpty
            ? 'Bertanda'
            : (d.status == 'late' && d.lateMinutes > 0 ? 'Telat ${d.lateMinutes}m' : d.statusLabel);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(Fmt.dayShort(d.workDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
            Text('${d.workDate.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              d.clockIn == null && d.clockOut == null
                  ? '—'
                  : '${Fmt.time(d.clockIn)} – ${working ? 'sekarang' : Fmt.time(d.clockOut)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              [d.shift ?? '', ...d.flags].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        StatusPill(label: label, tone: tone),
      ]),
    );
  }
}
