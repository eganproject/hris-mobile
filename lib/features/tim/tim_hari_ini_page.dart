import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

final teamTodayProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('team/today');
  return asMap(res['data']);
});

/// Kunci: `YYYY-MM-DD|1` (1 = bawahan langsung saja).
final teamDayProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final [date, direct] = key.split('|');
  final res = await ref.read(t2ApiProvider).get('team/today', query: {'date': date, if (direct == '1') 'direct': 1});
  return asMap(res['data']);
});

/// Status yang bisa dipilih, urut sesuai daftar.
const _states = <(String, String)>[
  ('not_yet', 'Belum absen'),
  ('late', 'Telat'),
  ('present', 'Hadir'),
  ('wfh', 'WFH'),
  ('leave', 'Cuti/izin'),
  ('off', 'Libur'),
];

/// Tim hari ini: siapa yang sudah masuk, telat, belum absen, cuti, atau WFH —
/// bisa dilihat untuk tanggal lain, dicari per nama, dan disaring per status.
/// Pencarian & status disaring di HP supaya langsung terasa tanpa menunggu server.
class TimHariIniPage extends ConsumerStatefulWidget {
  const TimHariIniPage({super.key, this.initialState});

  /// Bisa dibuka langsung tersaring, mis. dari chip "belum absen" di tab Tim.
  final String? initialState;

  @override
  ConsumerState<TimHariIniPage> createState() => _TimHariIniPageState();
}

class _TimHariIniPageState extends ConsumerState<TimHariIniPage> {
  final Set<int> _reminded = {};
  final _search = TextEditingController();
  late DateTime _date = _dayOnly(DateTime.now());
  late String? _state = widget.initialState;
  bool _direct = false;
  String _q = '';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

  Future<void> _pickDate() async {
    final today = _dayOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today,
      helpText: 'Lihat tim pada tanggal',
    );
    if (d != null) setState(() => _date = d);
  }

  void _shiftDate(int days) {
    final today = _dayOnly(DateTime.now());
    final next = _date.add(Duration(days: days));
    if (next.isAfter(today) || next.isBefore(today.subtract(const Duration(days: 90)))) return;
    setState(() => _date = next);
  }

  bool _matches(Map<String, dynamic> m) {
    if (_q.isEmpty) return true;
    final e = asMap(m['employee']);
    final hay = '${e['name'] ?? ''} ${e['job_title'] ?? ''} ${m['manager_name'] ?? ''}'.toLowerCase();
    return hay.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final key = '${ymd(_date)}|${_direct ? 1 : 0}';
    final value = ref.watch(teamDayProvider(key));
    final d = value.asData?.value;
    final today = _dayOnly(DateTime.now());
    final isToday = _date == today;
    final stateLabel = {for (final s in _states) s.$1: s.$2, if (!isToday) 'not_yet': 'Tidak absen'};

    return DotScaffold(
      child: Column(children: [
        BackHeader(
          title: isToday ? 'Tim hari ini' : 'Tim · ${dateLabel(ymd(_date))}',
          subtitle: d == null ? null : '${d['team_size']} anggota${isToday ? ' · per ${d['as_of']}' : ''}',
        ),
        const SizedBox(height: 12),
        // Baris filter: tanggal + cari.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MaxWidth(
            child: Column(children: [
              Row(children: [
                SquareIconButton(icon: Icons.chevron_left, tooltip: 'Hari sebelumnya', onTap: () => _shiftDate(-1)),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    radius: 12,
                    onTap: _pickDate,
                    child: Row(children: [
                      const Icon(Icons.calendar_month_outlined, size: 19, color: T2Colors.navy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(isToday ? 'Hari ini · ${dateLabel(ymd(_date), year: false)}' : dateLabel(ymd(_date)),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      if (!isToday)
                        GestureDetector(
                          onTap: () => setState(() => _date = today),
                          child: const Text('Hari ini', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: T2Colors.navy)),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: isToday ? .35 : 1,
                  child: SquareIconButton(icon: Icons.chevron_right, tooltip: 'Hari berikutnya', onTap: () => _shiftDate(1)),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau jabatan',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _search.clear();
                            _q = '';
                          }),
                        ),
                ),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // Chip status (dengan jumlah) + bawahan langsung; bisa digeser.
        SizedBox(
          height: 40,
          child: Builder(builder: (context) {
            final members = asList(d?['members']).where(_matches).toList();
            int count(String s) => members.where((m) => m['state'] == s).length;
            // Row (bukan ListView) agar semua chip selalu terbangun; jumlahnya sedikit.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Chip(label: 'Semua${d == null ? '' : ' ${members.length}'}', selected: _state == null, onTap: () => setState(() => _state = null)),
                for (final (k, _) in _states)
                  _Chip(
                    label: '${stateLabel[k]}${d == null ? '' : ' ${count(k)}'}',
                    selected: _state == k,
                    tone: k,
                    onTap: () => setState(() => _state = _state == k ? null : k),
                  ),
                Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), color: T2Colors.line),
                _Chip(
                  label: 'Bawahan langsung',
                  icon: _direct ? Icons.check_rounded : Icons.person_outline_rounded,
                  selected: _direct,
                  onTap: () => setState(() => _direct = !_direct),
                ),
              ]),
            );
          }),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncBody<Map<String, dynamic>>(
            value: value,
            onRefresh: () async => ref.invalidate(teamDayProvider(key)),
            builder: (d) {
              final members = asList(d['members']).where(_matches).where((m) => _state == null || m['state'] == _state).toList();
              return ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 40), children: [
                MaxWidth(
                  child: Column(children: [
                    if (members.isEmpty)
                      EmptyNote(
                        _q.isNotEmpty || _state != null ? 'Tidak ada anggota yang cocok dengan filter ini.' : 'Belum ada anggota tim.',
                        icon: Icons.groups_2_outlined,
                      ),
                    for (final m in members) ...[
                      _MemberRow(
                        row: m,
                        isToday: isToday,
                        reminded: _reminded.contains(asMap(m['employee'])['id']),
                        onRemind: () => _remind(asMap(m['employee'])),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ]),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.tone, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dot = switch (tone) {
      'not_yet' => AppColors.danger,
      'late' => AppColors.accentText,
      'present' => AppColors.success,
      'wfh' || 'leave' => AppColors.info,
      'off' => AppColors.faint,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.navy : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.navy : AppColors.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (dot != null) ...[
                Container(width: 7, height: 7, decoration: BoxDecoration(color: selected ? Colors.white : dot, shape: BoxShape.circle)),
                const SizedBox(width: 7),
              ],
              if (icon != null) ...[Icon(icon, size: 16, color: selected ? Colors.white : AppColors.chipText), const SizedBox(width: 6)],
              Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.chipText)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.row, required this.reminded, required this.onRemind, this.isToday = true});
  final Map<String, dynamic> row;
  final bool isToday;
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
      'not_yet' when !isToday => ('Tidak absen', 'danger'),
      'leave' => (schedule['label'] as String? ?? 'Cuti', 'accent'),
      'not_yet' => ('Belum absen', 'danger'),
      _ => ('Libur', 'neutral'),
    };
    final base = shift != null ? 'Shift ${shift['code'] ?? ''} · ${shift['start_time']}–${shift['end_time']}' : (schedule['label'] as String? ?? '');
    final sub = row['clock_out'] != null ? '$base · pulang ${row['clock_out']}' : base;

    return T2Card(
      onTap: emp['id'] == null ? null : () => context.push('/tim/anggota/${emp['id']}'),
      child: Row(children: [
        PersonAvatar(person: emp, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emp['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(sub, style: const TextStyle(fontSize: 12.5, color: T2Colors.muted)),
            if (row['manager_name'] is String)
              Text('Tim ${row['manager_name']}',
                  style: const TextStyle(fontSize: 12, color: T2Colors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusChip(label.trim(), tone: tone),
          if (state == 'not_yet' && isToday) ...[
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
