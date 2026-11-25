import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

final _shiftsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('shifts');
  return asList(res['data']);
});

/// Atur jadwal tim: grid mingguan anggota tim langsung. Ketuk sel untuk ganti
/// shift / WFH / libur, "Salin minggu lalu", lalu "Terbitkan" agar tim mengonfirmasi.
class JadwalTimPage extends ConsumerStatefulWidget {
  const JadwalTimPage({super.key});

  @override
  ConsumerState<JadwalTimPage> createState() => _JadwalTimPageState();
}

class _JadwalTimPageState extends ConsumerState<JadwalTimPage> {
  /// Senin minggu yang dibuka (bawaan: minggu depan, sama seperti server).
  late DateTime _weekStart;
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

  Future<void> _editCell(Map<String, dynamic> employee, Map<String, dynamic> day) async {
    if (day['editable'] != true) {
      showSnack(context, day['mode'] == 'leave' ? 'Hari ini sedang cuti/izin.' : 'Hari yang sudah lewat hanya bisa diubah HR dari web.');
      return;
    }
    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CellSheet(employee: employee, day: day),
    );
    if (choice == null) return;
    await _run((api) => api.put('team/schedule', data: {
          'employee_id': employee['id'],
          'date': day['date'],
          ...choice,
        }));
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
    final days = [for (var i = 0; i < 7; i++) _weekStart.add(Duration(days: i))];
    final published = g?['published_at'] != null;

    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BackHeader(title: 'Atur jadwal tim', subtitle: g == null ? null : '${g['team_size']} anggota${g['branch'] != null ? ' · ${g['branch']}' : ''}'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: T2Card(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(children: [
                IconButton(onPressed: _busy ? null : () => _shiftWeek(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                    '${_weekStart.day} ${monthShort(_weekStart)} – ${weekEnd.day} ${monthShort(weekEnd)} ${weekEnd.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(onPressed: _busy ? null : () => _shiftWeek(1), icon: const Icon(Icons.chevron_right)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (g != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                if ((g['unscheduled_days'] as num? ?? 0) > 0)
                  StatusChip('${g['unscheduled_days']} hari belum dijadwalkan', tone: 'warning'),
                StatusChip(
                  published ? 'Terbit · ${g['confirmed_count']}/${g['team_size']} konfirmasi' : 'Belum diterbitkan',
                  tone: published ? 'success' : 'neutral',
                ),
              ]),
            ),
          const SizedBox(height: 10),
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
                        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                          if (members.isEmpty) const EmptyNote('Belum ada anggota tim.', icon: Icons.groups_2_outlined),
                          if (members.isNotEmpty)
                            T2Card(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                              child: Column(children: [
                                Row(children: [
                                  const SizedBox(width: 92),
                                  for (final d in days)
                                    Expanded(
                                      child: Column(children: [
                                        Text(dayShort(d), style: const TextStyle(fontSize: 11, color: T2Colors.muted, fontWeight: FontWeight.w700)),
                                        Text('${d.day}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                      ]),
                                    ),
                                ]),
                                const SizedBox(height: 6),
                                for (final m in members) _GridRow(member: m, onTap: _editCell),
                              ]),
                            ),
                          const SizedBox(height: 10),
                          const Text(
                            'Kode: huruf = kode shift · W = WFH · L = libur · C = cuti/izin · DL = dinas luar · kosong = belum dijadwalkan. Ketuk sel untuk mengubah.',
                            style: TextStyle(fontSize: 12, color: T2Colors.muted, height: 1.4),
                          ),
                        ]),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || g == null ? null : () => _run((api) => api.post('team/schedule/copy-last-week', data: {'week_start': ymd(_weekStart)})),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Salin minggu lalu'),
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
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.member, required this.onTap});
  final Map<String, dynamic> member;
  final void Function(Map<String, dynamic> employee, Map<String, dynamic> day) onTap;

  @override
  Widget build(BuildContext context) {
    final emp = asMap(member['employee']);
    final days = asList(member['days']);
    final first = (emp['name'] as String? ?? '-').split(' ').first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 92,
          child: Row(children: [
            PersonAvatar(person: emp, size: 28),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(first, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (member['confirmed'] == true)
                  const Text('✓ konfirmasi', style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        for (final d in days)
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(emp, d),
              child: _Cell(day: d),
            ),
          ),
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day});
  final Map<String, dynamic> day;

  @override
  Widget build(BuildContext context) {
    final code = day['code'] as String?;
    final (bg, fg) = switch (day['mode']) {
      'off' => (const Color(0xFFF1F3F7), T2Colors.faint),
      'wfh' => (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      'leave' => (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
      'trip' => (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      'none' => (Colors.white, T2Colors.faint),
      _ => (T2Colors.orangeSoft, T2Colors.orangeText),
    };
    final editable = day['editable'] == true;
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: day['mode'] == 'none' ? Border.all(color: const Color(0xFFFDBA74), style: BorderStyle.solid) : null,
      ),
      child: Opacity(
        opacity: editable ? 1 : 0.55,
        child: Text(code ?? '–', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
      ),
    );
  }
}

/// Pilih isi sel: shift (opsional WFH) atau libur. Hasil = body PUT team/schedule.
class _CellSheet extends ConsumerStatefulWidget {
  const _CellSheet({required this.employee, required this.day});
  final Map<String, dynamic> employee;
  final Map<String, dynamic> day;

  @override
  ConsumerState<_CellSheet> createState() => _CellSheetState();
}

class _CellSheetState extends ConsumerState<_CellSheet> {
  late int? _shiftId = widget.day['shift_id'] as int?;
  late bool _wfh = widget.day['mode'] == 'wfh';

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(_shiftsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.employee['name'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(dateLabel(widget.day['date']), style: const TextStyle(color: T2Colors.muted)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: shifts.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: T2Colors.orange))),
              error: (e, _) => Text(t2Error(e)),
              data: (list) => ListView(shrinkWrap: true, children: [
                for (final s in list)
                  _OptionTile(
                    selected: _shiftId == s['id'],
                    title: '${s['code'] ?? ''} · ${s['name']}',
                    subtitle: '${s['start_time']} – ${s['end_time']}',
                    onTap: () => setState(() => _shiftId = s['id'] as int),
                  ),
              ]),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _wfh,
            activeThumbColor: T2Colors.orange,
            title: const Text('Kerja dari rumah (WFH)', style: TextStyle(fontWeight: FontWeight.w700)),
            onChanged: (v) => setState(() => _wfh = v),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, {'is_day_off': true}),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
                child: const Text('Jadikan libur', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: 'Simpan',
                onPressed: _shiftId == null ? null : () => Navigator.pop(context, {'shift_id': _shiftId, 'is_day_off': false, 'is_wfh': _wfh}),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.selected, required this.title, required this.subtitle, required this.onTap});
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? T2Colors.orangeSoft : T2Colors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? T2Colors.orange : Colors.transparent, width: 1.5),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: T2Colors.muted)),
                ]),
              ),
              if (selected) const Icon(Icons.check_circle, color: T2Colors.orange),
            ]),
          ),
        ),
      );
}
