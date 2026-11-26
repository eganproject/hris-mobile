import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/ui.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

final _shiftsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('shifts');
  return asList(res['data']);
});

/// Atur jadwal tim per hari: pilih hari di strip atas, lalu atur shift tiap
/// anggota lewat tombol besar. Satu pilihan bisa diterapkan ke beberapa hari
/// sekaligus. "Salin minggu lalu", lalu "Terbitkan" agar tim mengonfirmasi.
class JadwalTimPage extends ConsumerStatefulWidget {
  const JadwalTimPage({super.key});

  @override
  ConsumerState<JadwalTimPage> createState() => _JadwalTimPageState();
}

class _JadwalTimPageState extends ConsumerState<JadwalTimPage> {
  /// Senin minggu yang dibuka (bawaan: minggu depan, sama seperti server).
  late DateTime _weekStart;
  int _day = 0;
  Map<String, dynamic>? _grid;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _weekStart = monday.add(const Duration(days: 7));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(t2ApiProvider).get('team/schedule', query: {'week_start': ymd(_weekStart)});
      setState(() => _grid = asMap(res['data']));
    } catch (e) {
      setState(() => _error = t2Error(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftWeek(int weeks) {
    _weekStart = _weekStart.add(Duration(days: 7 * weeks));
    final today = DateTime.now();
    final todayIndex = DateTime(today.year, today.month, today.day).difference(_weekStart).inDays;
    _day = todayIndex >= 0 && todayIndex < 7 ? todayIndex : 0;
    _load();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function(T2Api api) call) async {
    setState(() => _busy = true);
    try {
      final res = await call(ref.read(t2ApiProvider));
      setState(() => _grid = asMap(res['data']));
      if (mounted && res['message'] is String) showSnack(context, res['message'] as String);
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> member) async {
    final days = asList(member['days']);
    final day = days[_day];
    if (day['editable'] != true) {
      showSnack(context, day['mode'] == 'leave' ? 'Hari ini sedang cuti/izin.' : 'Hari yang sudah lewat hanya bisa diubah HR dari web.');
      return;
    }
    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ShiftSheet(employee: asMap(member['employee']), days: days, dayIndex: _day),
    );
    if (choice == null) return;
    await _run((api) => api.put('team/schedule', data: {'employee_id': asMap(member['employee'])['id'], ...choice}));
  }

  Future<void> _publish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terbitkan jadwal?'),
        content: const Text('Semua anggota tim mendapat notifikasi dan diminta mengonfirmasi jadwal minggu ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terbitkan')),
        ],
      ),
    );
    if (ok == true) await _run((api) => api.post('team/schedule/publish', data: {'week_start': ymd(_weekStart)}));
  }

  @override
  Widget build(BuildContext context) {
    final g = _grid;
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final members = g == null ? const <Map<String, dynamic>>[] : asList(g['members']);
    final dates = [for (var i = 0; i < 7; i++) _weekStart.add(Duration(days: i))];
    final published = g?['published_at'] != null;
    final selected = dates[_day];

    // Ringkasan hari terpilih: jumlah per shift/WFH/libur/cuti/belum.
    final summary = <String, ({int n, String mode})>{};
    for (final m in members) {
      final d = asList(m['days'])[_day];
      final key = _CellStyle.title(d);
      summary[key] = (n: (summary[key]?.n ?? 0) + 1, mode: d['mode'] as String? ?? 'none');
    }
    bool hasGap(int i) => members.any((m) => asList(m['days'])[i]['mode'] == 'none');

    return DotScaffold(
      child: SafeArea(
        child: MaxWidth(
          width: 720,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BackHeader(
              title: 'Jadwal tim',
              subtitle: g == null ? null : '${g['team_size']} anggota${g['branch'] != null ? ' · ${g['branch']}' : ''}',
              trailing: g == null
                  ? null
                  : StatusChip(
                      published ? 'Terbit · ${g['confirmed_count']}/${g['team_size']}' : 'Belum terbit',
                      tone: published ? 'success' : 'neutral',
                    ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                IconButton(tooltip: 'Minggu sebelumnya', onPressed: _busy ? null : () => _shiftWeek(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: Text(
                    '${_weekStart.day} ${monthShort(_weekStart)} – ${weekEnd.day} ${monthShort(weekEnd)} ${weekEnd.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(tooltip: 'Minggu berikutnya', onPressed: _busy ? null : () => _shiftWeek(1), icon: const Icon(Icons.chevron_right_rounded)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _DayButton(date: dates[i], selected: i == _day, warn: hasGap(i), onTap: () => setState(() => _day = i))),
                ],
              ]),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading && g == null
                  ? const Center(child: CircularProgressIndicator(color: T2Colors.orange))
                  : _error != null && g == null
                      ? ListView(children: [
                          EmptyNote(_error!, icon: Icons.wifi_off_rounded),
                          Center(child: TextButton(onPressed: _load, child: const Text('Coba lagi'))),
                        ])
                      : RefreshIndicator(
                          color: T2Colors.orange,
                          onRefresh: _load,
                          child: members.isEmpty
                              ? ListView(children: const [EmptyNote('Belum ada anggota tim.', icon: Icons.groups_2_outlined)])
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                                  children: [
                                    // Ringkasan & judul hari ikut menggulir supaya layar pendek tetap lega.
                                    if (summary.isNotEmpty)
                                      Wrap(spacing: 8, runSpacing: 6, children: [
                                        for (final e in summary.entries) _SummaryChip(label: '${e.key} ${e.value.n}', mode: e.value.mode),
                                      ]),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                                      child: Text('${dayLong(selected)}, ${selected.day} ${monthLong(selected)}'.toUpperCase(),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: T2Colors.faint)),
                                    ),
                                    for (final m in members) ...[
                                      _MemberRow(member: m, dayIndex: _day, onTap: _busy ? null : () => _edit(m)),
                                      const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: T2Colors.line))),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || g == null ? null : () => _run((api) => api.post('team/schedule/copy-last-week', data: {'week_start': ymd(_weekStart)})),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const FittedBox(child: Text('Salin minggu lalu')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      foregroundColor: T2Colors.navy,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: published ? 'Terbitkan ulang' : 'Terbitkan',
                    busy: _busy,
                    onPressed: g == null || members.isEmpty ? null : _publish,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Warna & teks tombol shift per mode hari.
class _CellStyle {
  static ({Color bg, Color fg, bool dashed}) of(String? mode) => switch (mode) {
        'off' => (bg: const Color(0xFFF1F3F7), fg: T2Colors.muted, dashed: false),
        'wfh' || 'trip' => (bg: const Color(0xFFE0F2FE), fg: const Color(0xFF075985), dashed: false),
        'leave' => (bg: const Color(0xFFF1ECFE), fg: const Color(0xFF5B21B6), dashed: false),
        'none' || null => (bg: Colors.white, fg: const Color(0xFFB42318), dashed: true),
        _ => (bg: T2Colors.orangeSoft, fg: T2Colors.orangeText, dashed: false),
      };

  static String title(Map<String, dynamic> d) => switch (d['mode']) {
        'off' => 'Libur',
        'wfh' => 'WFH',
        'trip' => 'Dinas luar',
        'leave' => 'Cuti',
        'none' || null => 'Belum',
        _ => (d['shift_name'] as String?) ?? (d['code'] as String? ?? 'Shift'),
      };

  static String subtitle(Map<String, dynamic> d) => switch (d['mode']) {
        'none' || null => 'Belum diatur',
        'off' => 'Hari off',
        'leave' => (d['label'] as String?) ?? 'Cuti/izin',
        _ => (d['time'] as String?)?.replaceAll(' – ', '–') ?? '',
      };
}

class _DayButton extends StatelessWidget {
  const _DayButton({required this.date, required this.selected, required this.warn, required this.onTap});
  final DateTime date;
  final bool selected;
  final bool warn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : T2Colors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '${dayLong(date)} ${date.day}${warn ? ', ada yang belum dijadwalkan' : ''}',
      child: Material(
        color: selected ? T2Colors.navy : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(dayShort(date), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg.withValues(alpha: .8))),
              FittedBox(child: Text('${date.day}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg))),
              const SizedBox(height: 3),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: warn ? (selected ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)) : Colors.transparent,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.mode});
  final String label;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final s = _CellStyle.of(mode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: mode == 'none' ? const Color(0xFFFEF2F2) : s.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: s.fg)),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.dayIndex, required this.onTap});
  final Map<String, dynamic> member;
  final int dayIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final emp = asMap(member['employee']);
    final day = asList(member['days'])[dayIndex];
    final style = _CellStyle.of(day['mode'] as String?);
    final editable = day['editable'] == true;
    final sub = [
      if (member['manager_name'] is String) 'Tim ${member['manager_name']}' else emp['job_title'],
      if (member['confirmed'] == true) '✓ konfirmasi',
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return T2Card(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(children: [
        PersonAvatar(person: emp, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emp['name'] as String? ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: T2Colors.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Ubah jadwal ${emp['name']}',
          child: Opacity(
            opacity: editable ? 1 : .6,
            child: Material(
              color: style.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: style.dashed ? const BorderSide(color: Color(0xFFF2A5A0), width: 1.5) : BorderSide.none,
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 108, maxWidth: 140, minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(day['mode'] == 'none' ? '+ Atur' : _CellStyle.title(day),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: style.fg)),
                      Text(_CellStyle.subtitle(day),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: style.fg.withValues(alpha: .85))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Lembar ubah shift: pilih shift / libur, WFH, lalu terapkan ke satu atau
/// beberapa hari (hanya hari yang masih bisa diubah).
class _ShiftSheet extends ConsumerStatefulWidget {
  const _ShiftSheet({required this.employee, required this.days, required this.dayIndex});
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>> days;
  final int dayIndex;

  @override
  ConsumerState<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends ConsumerState<_ShiftSheet> {
  int? _shiftId;
  bool _off = false;
  bool _wfh = false;
  late final Set<int> _picked = {widget.dayIndex};

  @override
  void initState() {
    super.initState();
    final d = widget.days[widget.dayIndex];
    _shiftId = (d['shift_id'] as num?)?.toInt();
    _off = d['mode'] == 'off';
    _wfh = d['mode'] == 'wfh';
  }

  bool _editable(int i) => widget.days[i]['editable'] == true;

  void _pickRange(Iterable<int> range) => setState(() {
        _picked
          ..clear()
          ..addAll(range.where(_editable));
        if (_picked.isEmpty) _picked.add(widget.dayIndex);
      });

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(_shiftsProvider);
    final day = DateTime.tryParse(widget.days[widget.dayIndex]['date'] as String? ?? '') ?? DateTime.now();
    final canSave = _off || _shiftId != null;
    final cols = MediaQuery.sizeOf(context).width >= 520 ? 3 : 2;

    Widget option({required bool selected, required String title, required String subtitle, required VoidCallback onTap}) => Material(
          color: selected ? T2Colors.orangeSoft : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? T2Colors.orange : const Color(0xFFE2E6ED), width: selected ? 2 : 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: selected ? T2Colors.orangeText : T2Colors.ink)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: T2Colors.muted)),
              ]),
            ),
          ),
        );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          PersonAvatar(person: widget.employee, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.employee['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${dayLong(day)}, ${day.day} ${monthLong(day)}', style: const TextStyle(fontSize: 12.5, color: T2Colors.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        const Text('PILIH SHIFT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: T2Colors.faint)),
        const SizedBox(height: 8),
        shifts.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: T2Colors.orange))),
          error: (e, _) => Text(t2Error(e), style: const TextStyle(color: Color(0xFFB91C1C))),
          // Wrap + lebar terhitung: tinggi kotak mengikuti isi, jadi tidak pernah terpotong di HP kecil.
          data: (list) => LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 8 * (cols - 1)) / cols;
            Widget cell(Widget child) => SizedBox(width: w, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 58), child: child));
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in list)
                cell(option(
                  selected: !_off && _shiftId == s['id'],
                  title: '${s['name']} (${s['code']})',
                  subtitle: '${s['start_time']}–${s['end_time']}',
                  onTap: () => setState(() {
                    _shiftId = (s['id'] as num).toInt();
                    _off = false;
                  }),
                )),
              cell(option(selected: _off, title: 'Libur', subtitle: 'Hari off', onTap: () => setState(() => _off = true))),
            ]);
          }),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _wfh && !_off,
          activeThumbColor: T2Colors.orange,
          title: const Text('Kerja dari rumah (WFH)', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Memakai jam shift yang dipilih', style: TextStyle(fontSize: 12.5)),
          onChanged: _off ? null : (v) => setState(() => _wfh = v),
        ),
        const SizedBox(height: 8),
        const Text('TERAPKAN JUGA KE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: T2Colors.faint)),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                selected: _picked.contains(i),
                child: Material(
                  color: _picked.contains(i) ? T2Colors.navy : const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: !_editable(i)
                        ? null
                        : () => setState(() {
                              if (_picked.contains(i) && _picked.length > 1) {
                                _picked.remove(i);
                              } else {
                                _picked.add(i);
                              }
                            }),
                    child: SizedBox(
                      height: 46,
                      child: Center(
                        child: FittedBox(
                          child: Text(
                            dayShort(DateTime.tryParse(widget.days[i]['date'] as String? ?? '') ?? day),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: _picked.contains(i) ? Colors.white : (_editable(i) ? const Color(0xFF4B5468) : const Color(0xFFB6BDC9)),
                              decoration: _editable(i) ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ActionChip(label: const Text('Sen–Jum'), onPressed: () => _pickRange(List.generate(5, (i) => i))),
          ActionChip(label: const Text('Seminggu'), onPressed: () => _pickRange(List.generate(7, (i) => i))),
          ActionChip(label: const Text('Hari ini saja'), onPressed: () => _pickRange([widget.dayIndex])),
        ]),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _picked.length > 1 ? 'Simpan untuk ${_picked.length} hari' : 'Simpan',
          onPressed: !canSave
              ? null
              : () => Navigator.pop(context, {
                    'dates': [for (final i in (_picked.toList()..sort())) widget.days[i]['date']],
                    'is_day_off': _off,
                    if (!_off) 'shift_id': _shiftId,
                    'is_wfh': _wfh && !_off,
                  }),
        ),
      ]),
    );
  }
}
