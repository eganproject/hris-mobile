import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_ui.dart';

final orgProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('org');
  return asMap(res['data']);
});

/// Struktur organisasi dari sudut pandang saya: ke atas hanya atasan langsung,
/// ke bawah seluruh tim (semua level, bisa dibuka-tutup).
class StrukturPage extends ConsumerWidget {
  const StrukturPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orgProvider);
    final d = value.asData?.value;
    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(children: [
          BackHeader(
            title: 'Struktur organisasi',
            subtitle: d == null ? null : [d['department'], d['branch']].whereType<String>().join(' · '),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: value,
              onRefresh: () async => ref.invalidate(orgProvider),
              builder: (d) {
                final manager = d['manager'] is Map ? asMap(d['manager']) : null;
                final subs = asList(d['subordinates']);
                return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
                  if (manager != null) ...[
                    const _Label('ATASAN LANGSUNG'),
                    _PersonCard(person: manager),
                    const _Connector(),
                  ],
                  const _Label('SAYA'),
                  _PersonCard(person: asMap(d['me']), highlight: true),
                  if (subs.isNotEmpty) ...[
                    const _Connector(),
                    _Label('TIM SAYA · ${subs.length} langsung, ${d['subordinate_total']} total'),
                    for (final s in subs) _Node(node: s, depth: 0),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: T2Colors.faint)),
      );
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 2, height: 22, margin: const EdgeInsets.symmetric(vertical: 4), color: T2Colors.line),
      );
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, this.highlight = false, this.trailing, this.onTap});
  final Map<String, dynamic> person;
  final bool highlight;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return T2Card(
      onTap: onTap,
      color: highlight ? T2Colors.orangeSoft : Colors.white,
      child: Row(children: [
        PersonAvatar(person: person, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(person['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(
              [person['job_title'], person['department']].whereType<String>().join(' · '),
              style: const TextStyle(fontSize: 12.5, color: T2Colors.muted),
            ),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Satu simpul pohon bawahan; anak-anaknya dibuka dengan ketukan.
class _Node extends StatefulWidget {
  const _Node({required this.node, required this.depth});
  final Map<String, dynamic> node;
  final int depth;

  @override
  State<_Node> createState() => _NodeState();
}

class _NodeState extends State<_Node> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final children = asList(widget.node['children']);
    final direct = (widget.node['direct_count'] as num?)?.toInt() ?? children.length;
    final total = (widget.node['total_count'] as num?)?.toInt() ?? direct;
    return Padding(
      padding: EdgeInsets.only(left: widget.depth == 0 ? 0 : 18, top: 8),
      child: Container(
        decoration: widget.depth == 0
            ? null
            : const BoxDecoration(border: Border(left: BorderSide(color: T2Colors.line, width: 2))),
        padding: EdgeInsets.only(left: widget.depth == 0 ? 0 : 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PersonCard(
            person: widget.node,
            onTap: children.isEmpty ? null : () => setState(() => _open = !_open),
            trailing: children.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    StatusChip(total > direct ? '$direct · $total' : '$direct', tone: 'neutral'),
                    Icon(_open ? Icons.expand_less : Icons.expand_more, color: T2Colors.faint),
                  ]),
          ),
          if (_open)
            for (final c in children) _Node(node: c, depth: widget.depth + 1),
        ]),
      ),
    );
  }
}
