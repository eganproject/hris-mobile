import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';

final teamTodayProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('team/today');
  return asMap(res['data']);
});

/// Tim hari ini: siapa yang sudah masuk, telat, belum absen, cuti, atau WFH.
class TimHariIniPage extends ConsumerStatefulWidget {
  const TimHariIniPage({super.key});

  @override
  ConsumerState<TimHariIniPage> createState() => _TimHariIniPageState();
}

class _TimHariIniPageState extends ConsumerState<TimHariIniPage> {
  final Set<int> _reminded = {};

  Future<void> _remind(Map<String, dynamic> employee) async {
    final id = employee['id'] as int;
    try {
      final res = await ref.read(t2ApiProvider).post('team/$id/remind');
      setState(() => _reminded.add(id));
      if (mounted) showSnack(context, res['message'] as String? ?? 'Pengingat terkirim.');
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(teamTodayProvider);
    final d = value.asData?.value;

    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(children: [
          BackHeader(
            title: 'Tim hari ini',
            subtitle: d == null ? null : '${d['team_size']} anggota · per ${d['as_of']}',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: value,
              onRefresh: () async => ref.invalidate(teamTodayProvider),
              builder: (d) {
                final counts = asMap(d['counts']);
                final members = asList(d['members']);
                return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
                  Row(children: [
                    _Count('Hadir', counts['present'], const Color(0xFF15803D)),
                    const SizedBox(width: 8),
                    _Count('Telat', counts['late'], const Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    _Count('Belum', counts['not_yet'], const Color(0xFFB91C1C)),
                    const SizedBox(width: 8),
                    _Count('Cuti', counts['leave'], T2Colors.navy),
                  ]),
                  const SizedBox(height: 16),
                  if (members.isEmpty) const EmptyNote('Belum ada anggota tim.', icon: Icons.groups_2_outlined),
                  for (final m in members) ...[
                    _MemberRow(
                      row: m,
                      reminded: _reminded.contains(asMap(m['employee'])['id']),
                      onRemind: () => _remind(asMap(m['employee'])),
                    ),
                    const SizedBox(height: 10),
                  ],
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.color);
  final String label;
  final dynamic value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: T2Card(
          padding: const EdgeInsets.symmetric(vertical: 12),
          radius: 18,
          child: Column(children: [
            Text('${value ?? 0}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: T2Colors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.row, required this.reminded, required this.onRemind});
  final Map<String, dynamic> row;
  final bool reminded;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final emp = asMap(row['employee']);
    final schedule = asMap(row['schedule']);
    final shift = schedule['shift'] is Map ? asMap(schedule['shift']) : null;
    final state = row['state'] as String? ?? 'off';
    final late = (row['late_minutes'] as num?)?.toInt() ?? 0;

    final (label, tone) = switch (state) {
      'present' => ('Masuk ${row['clock_in'] ?? ''}', 'success'),
      'late' => ('Telat $late mnt', 'warning'),
      'wfh' => ('WFH ${row['clock_in'] ?? ''}', 'info'),
      'leave' => (schedule['label'] as String? ?? 'Cuti', 'accent'),
      'not_yet' => ('Belum absen', 'danger'),
      _ => ('Libur', 'neutral'),
    };
    final sub = shift != null ? 'Shift ${shift['code'] ?? ''} · ${shift['start_time']}–${shift['end_time']}' : (schedule['label'] as String? ?? '');

    return T2Card(
      child: Row(children: [
        PersonAvatar(person: emp, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emp['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(sub, style: const TextStyle(fontSize: 12.5, color: T2Colors.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusChip(label.trim(), tone: tone),
          if (state == 'not_yet') ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: reminded ? null : onRemind,
              child: Text(
                reminded ? 'Diingatkan' : 'Ingatkan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: reminded ? T2Colors.faint : T2Colors.orangeText,
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
