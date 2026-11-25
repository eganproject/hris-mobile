import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../pengajuan/pengajuan_widgets.dart';
import '../profil/profil_providers.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

/// GET /approvals?type=… → {data: [...], meta: {total, counts}}
final approvalsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, type) async {
  return ref.read(t2ApiProvider).get('approvals', query: {'type': type});
});

/// Persetujuan atasan: cuti/izin/sakit dan lembur bawahan langsung (HR bisa ambil alih).
class PersetujuanPage extends ConsumerStatefulWidget {
  const PersetujuanPage({super.key});

  @override
  ConsumerState<PersetujuanPage> createState() => _PersetujuanPageState();
}

class _PersetujuanPageState extends ConsumerState<PersetujuanPage> {
  String _type = 'semua';
  final Set<String> _busy = {};

  static const _filters = [('semua', 'Semua'), ('cuti', 'Cuti'), ('izin', 'Izin'), ('sakit', 'Sakit'), ('lembur', 'Lembur')];

  void _refresh() {
    ref.invalidate(approvalsProvider);
    ref.invalidate(profileProvider);
  }

  Future<void> _decide(Map<String, dynamic> item, bool approve) async {
    String? notes;
    if (!approve) {
      notes = await _askReason(context);
      if (notes == null) return;
    }
    final key = '${item['kind']}-${item['id']}';
    setState(() => _busy.add(key));
    try {
      final res = await ref.read(t2ApiProvider).post(
            'approvals/${item['kind']}/${item['id']}/${approve ? 'approve' : 'reject'}',
            data: approve ? null : {'notes': notes!.isEmpty ? null : notes},
          );
      if (mounted) showSnack(context, (res['message'] as String?) ?? (approve ? 'Disetujui.' : 'Ditolak.'));
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
      _refresh();
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(approvalsProvider(_type));
    final counts = value.asData?.value['meta'] is Map ? Map<String, dynamic>.from(value.asData!.value['meta']['counts'] as Map? ?? {}) : <String, dynamic>{};
    final total = counts.values.fold<int>(0, (a, b) => a + ((b as num?)?.toInt() ?? 0));

    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BackHeader(title: 'Persetujuan', subtitle: value.hasValue ? '$total menunggu keputusan Anda' : null),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final (key, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(key == 'semua' || (counts[key] ?? 0) == 0 ? label : '$label ${counts[key]}'),
                      selected: _type == key,
                      showCheckmark: false,
                      selectedColor: T2Colors.navy,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _type == key ? Colors.white : T2Colors.ink,
                      ),
                      onSelected: (_) => setState(() => _type = key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: value,
              onRefresh: () async => _refresh(),
              builder: (res) {
                final items = asList(res['data']);
                if (items.isEmpty) {
                  return ListView(children: const [EmptyNote('Tidak ada pengajuan yang menunggu.', icon: Icons.task_alt)]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ApprovalCard(
                    item: items[i],
                    busy: _busy.contains('${items[i]['kind']}-${items[i]['id']}'),
                    onApprove: () => _decide(items[i], true),
                    onReject: () => _decide(items[i], false),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Minta alasan penolakan. null = batal; string kosong = tanpa alasan.
Future<String?> _askReason(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tolak pengajuan?'),
      content: TextField(controller: ctrl, maxLines: 3, decoration: t2Input('Alasan (opsional)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Tolak', style: TextStyle(color: Color(0xFFB91C1C))),
        ),
      ],
    ),
  );
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.item, required this.busy, required this.onApprove, required this.onReject});
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final emp = asMap(item['employee']);
    final style = categoryStyle(item['category'] as String?);
    final isOvertime = item['kind'] == 'overtime';
    final when = isOvertime
        ? '${dateLabel(item['work_date'])} · ${item['start_time'] ?? ''}–${item['end_time'] ?? ''}'
        : rangeLabel(item['start_date'], item['end_date']);

    return T2Card(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(person: emp, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emp['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                [emp['job_title'], relativeTime(item['submitted_at'])].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(color: T2Colors.muted, fontSize: 12.5),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(99)),
            child: Text(_categoryLabel(item['category'] as String?), style: TextStyle(color: style.fg, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(item['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(when, style: const TextStyle(color: T2Colors.muted, fontSize: 13)),
        if ((item['reason'] as String?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: T2Colors.bg, borderRadius: BorderRadius.circular(14)),
            child: Text('“${item['reason']}”', style: const TextStyle(fontSize: 13.5, color: T2Colors.ink)),
          ),
        ],
        if (item['as_hr'] == true) ...[
          const SizedBox(height: 8),
          const StatusChip('Diambil alih HR', tone: 'info'),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onReject,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
                foregroundColor: const Color(0xFFB91C1C),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
              child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onApprove,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
                backgroundColor: T2Colors.orange,
              ),
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }
}

String _categoryLabel(String? c) => switch (c) {
      'izin' => 'Izin',
      'sakit' => 'Sakit',
      'lembur' => 'Lembur',
      _ => 'Cuti',
    };
