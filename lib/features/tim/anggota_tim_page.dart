import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

/// Kunci: `id|YYYY-MM`.
final teamMemberProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final [id, month] = key.split('|');
  final res = await ref.read(t2ApiProvider).get('team/members/$id', query: {'month': month});
  return asMap(res['data']);
});

String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Profil anggota tim dan riwayat absennya per bulan (khusus atasan).
class AnggotaTimPage extends ConsumerStatefulWidget {
  const AnggotaTimPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<AnggotaTimPage> createState() => _AnggotaTimPageState();
}

class _AnggotaTimPageState extends ConsumerState<AnggotaTimPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final key = '${widget.id}|${_ym(_month)}';
    final value = ref.watch(teamMemberProvider(key));
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;

    return DotScaffold(
      child: Column(
        children: [
          const BackHeader(title: 'Anggota tim'),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: value,
              onRefresh: () async => ref.invalidate(teamMemberProvider(key)),
              builder: (d) {
                final p = asMap(d['person']);
                final manager = asMap(p['manager']);
                final sum = asMap(d['summary']);
                final items = asList(d['items']);
                int n(String k) => (sum[k] as num?)?.toInt() ?? 0;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  children: [
                    MaxWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NavyHeroCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                  child: PersonAvatar(person: p, size: 58),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'] as String? ?? '-',
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                      if (p['job_title'] != null)
                                        Text(p['job_title'] as String, style: const TextStyle(fontSize: 13, color: Color(0xCCFFFFFF))),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (p['department'] != null)
                                            StatusPill(label: p['department'] as String, tone: PillTone.onPrimary),
                                          if (p['branch'] != null) StatusPill(label: p['branch'] as String, tone: PillTone.onPrimary),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppCard(
                            child: Column(
                              children: [
                                _Info(
                                  Icons.supervisor_account_outlined,
                                  'Atasan',
                                  manager['name'] == null ? '-' : '${manager['name']}${p['is_direct'] == true ? ' (kamu)' : ''}',
                                ),
                                if (p['joined'] != null) ...[
                                  const SizedBox(height: 10),
                                  _Info(Icons.event_available_outlined, 'Bergabung', () {
                                    final j = DateTime.parse('${p['joined']}-01');
                                    return '${monthLong(j)} ${j.year}';
                                  }()),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              SquareIconButton(
                                icon: Icons.chevron_left,
                                tooltip: 'Bulan sebelumnya',
                                onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                              ),
                              Expanded(
                                child: Text(
                                  'Riwayat absen · ${monthLong(_month)} ${_month.year}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Opacity(
                                opacity: isThisMonth ? .35 : 1,
                                child: SquareIconButton(
                                  icon: Icons.chevron_right,
                                  tooltip: 'Bulan berikutnya',
                                  onTap: isThisMonth ? () {} : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _Stat('Hadir', n('present'), AppColors.success),
                              const SizedBox(width: 8),
                              _Stat('Telat', n('late'), AppColors.accentText),
                              const SizedBox(width: 8),
                              _Stat('Cuti/izin', n('leave'), AppColors.info),
                              const SizedBox(width: 8),
                              _Stat('Alfa', n('absent'), AppColors.danger),
                            ],
                          ),
                          if (n('late_minutes') > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Text(
                                'Total terlambat ${minutesLabel(n('late_minutes'))} bulan ini',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            const EmptyNote('Belum ada catatan absen di bulan ini.', icon: Icons.event_note_outlined)
                          else
                            AppCard(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [for (final (i, r) in items.indexed) _DayRow(row: r, last: i == items.length - 1)],
                              ),
                            ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/tim/jadwal'),
                            icon: const Icon(Icons.calendar_view_week_outlined, size: 20),
                            label: const Text('Atur jadwal tim'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: AppColors.navy),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

String? _tone(String? status) => switch (status) {
  'present' => 'success',
  'late' || 'early_leave' => 'warning',
  'absent' => 'danger',
  'leave' || 'permit' || 'sick' || 'business_trip' || 'wfh' => 'info',
  _ => null,
};

class _DayRow extends StatelessWidget {
  const _DayRow({required this.row, required this.last});
  final Map<String, dynamic> row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(row['work_date'] as String);
    final inT = parseDate(row['clock_in']);
    final outT = parseDate(row['clock_out']);
    final late = (row['late_minutes'] as num?)?.toInt() ?? 0;
    final times = inT == null && outT == null ? null : '${inT == null ? '--:--' : hm(inT)} – ${outT == null ? '--:--' : hm(outT)}';
    final sub = [row['shift'], times, if (late > 0) 'telat $late mnt'].whereType<String>().join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text(
                  dayShort(d).toUpperCase(),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                Text('${d.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.isEmpty ? '-' : sub, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                if (row['note'] is String && (row['note'] as String).isNotEmpty)
                  Text(
                    row['note'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(row['status_label'] as String? ?? '-', tone: _tone(row['status'] as String?)),
        ],
      ),
    );
  }
}
