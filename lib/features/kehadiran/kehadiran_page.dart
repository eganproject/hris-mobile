import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../core/widgets/ui.dart';
import '../absen/attendance_models.dart';
import '../absen/attendance_repository.dart';
import '../jadwal/jadwal_page.dart';

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

/// Tab Kehadiran: riwayat absensi per bulan dan jadwal saya per minggu.
/// Absen sendiri dilakukan di tablet kantor atau mesin gudang.
class KehadiranPage extends StatefulWidget {
  const KehadiranPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<KehadiranPage> createState() => _KehadiranPageState();
}

class _KehadiranPageState extends State<KehadiranPage> {
  late int _tab = widget.initialTab;

  @override
  void didUpdateWidget(KehadiranPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return DotScaffold(
      child: Column(children: [
        const TabHeader(title: 'Kehadiran', subtitle: 'Tercatat dari tablet kantor dan mesin gudang'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: SegmentedTabs(labels: const ['Riwayat', 'Jadwal saya'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: const [
            _RiwayatView(),
            JadwalView(bottomPadding: 110),
          ]),
        ),
      ]),
    );
  }
}

class _RiwayatView extends ConsumerWidget {
  const _RiwayatView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_monthProvider);
    final history = ref.watch(_historyProvider);
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => ref.refresh(_historyProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          NavyHeroCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Column(children: [
              Row(children: [
                _monthButton(Icons.chevron_left, 'Bulan sebelumnya', () => ref.read(_monthProvider.notifier).shift(-1)),
                Expanded(
                  child: Text(Fmt.monthYear(month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                _monthButton(Icons.chevron_right, 'Bulan berikutnya',
                    isCurrent ? null : () => ref.read(_monthProvider.notifier).shift(1)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _stat(history.value?.present, 'Hadir'),
                _stat(history.value?.late, 'Terlambat'),
                _stat(history.value?.absent, 'Alpa'),
                _stat(history.value?.flagged, 'Bertanda'),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          ...history.when(
            loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(apiErrorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              ),
            ],
            data: (h) => [
              if (h.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Belum ada absensi bulan ini.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                ),
              for (final d in h.items) ...[_dayRow(d), const SizedBox(height: 8)],
            ],
          ),
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.all(14),
            onTap: () => context.push('/koreksi'),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.accentText, size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ada yang salah atau lupa absen?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Ajukan koreksi ke atasan / HR', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _monthButton(IconData icon, String tooltip, VoidCallback? onTap) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white),
      );

  Widget _stat(int? value, String label) => Expanded(
        child: Column(children: [
          Text(value == null ? '–' : '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xB3FFFFFF), fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _dayRow(AttendanceDay d) {
    final working = d.clockIn != null && d.clockOut == null;
    final tone = d.flags.isNotEmpty
        ? PillTone.warning
        : switch (d.status) {
            'present' => PillTone.success,
            'wfh' || 'business_trip' || 'leave' || 'sick' || 'permission' => PillTone.info,
            'late' || 'early_leave' => PillTone.warning,
            'absent' => PillTone.danger,
            _ => PillTone.neutral,
          };
    final label = working
        ? 'Bekerja'
        : d.flags.isNotEmpty
            ? 'Bertanda'
            : (d.status == 'late' && d.lateMinutes > 0 ? 'Telat ${d.lateMinutes} mnt' : d.statusLabel);

    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 14,
      child: Row(children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(Fmt.dayShort(d.workDate), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
            Text('${d.workDate.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              d.clockIn == null && d.clockOut == null
                  ? '—'
                  : '${Fmt.time(d.clockIn)} – ${working ? 'belum pulang' : Fmt.time(d.clockOut)}',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 1),
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
