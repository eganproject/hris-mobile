import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

/// GET /people?q= → {data: [person + online, last_seen_at], meta: {online_count, offline_count}}
final peopleProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, q) async {
  return ref.read(t2ApiProvider).get('people', query: {if (q.isNotEmpty) 'q': q, 'limit': 300});
});

final personProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ref.read(t2ApiProvider).get('people/$id');
  return asMap(res['data']);
});

/// Rekan kerja: cari nama/jabatan/divisi, titik hijau bila sedang aktif di aplikasi.
class RekanView extends ConsumerStatefulWidget {
  const RekanView({super.key, this.bottomPadding = 110});

  final double bottomPadding;

  @override
  ConsumerState<RekanView> createState() => _RekanViewState();
}

class _RekanViewState extends ConsumerState<RekanView> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _q = v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(peopleProvider(_q));
    final meta = value.asData?.value['meta'];
    final online = meta is Map ? (meta['online_count'] as num?)?.toInt() : null;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: TextField(
          controller: _search,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cari nama, jabatan, atau divisi',
            prefixIcon: Icon(Icons.search, size: 20),
            isDense: true,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          Expanded(
            child: Text(online == null ? ' ' : '$online sedang aktif di aplikasi',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          GestureDetector(
            onTap: () => context.push('/struktur'),
            child: const Row(children: [
              Icon(Icons.account_tree_outlined, size: 16, color: AppColors.navy),
              SizedBox(width: 4),
              Text('Struktur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: AsyncBody<Map<String, dynamic>>(
          value: value,
          onRefresh: () async => ref.invalidate(peopleProvider(_q)),
          builder: (res) {
            final people = asList(res['data']);
            if (people.isEmpty) {
              return ListView(children: [EmptyNote(_q.isEmpty ? 'Belum ada rekan kerja.' : 'Tidak ada yang cocok dengan "$_q".', icon: Icons.person_search_outlined)]);
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(20, 0, 20, widget.bottomPadding),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _PersonRow(people[i]),
            );
          },
        ),
      ),
    ]);
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(this.p);
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final online = p['online'] == true;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 14,
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _PersonSheet(id: p['id'] as int, summary: p),
      ),
      child: Row(children: [
        Stack(children: [
          PersonAvatar(person: p, size: 40),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: online ? const Color(0xFF17B26A) : AppColors.inputLine,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            Text(
              [p['job_title'], p['department']].whereType<String>().join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ]),
        ),
        Text(online ? 'Aktif' : relativeTime(p['last_seen_at']),
            style: TextStyle(fontSize: 11.5, color: online ? AppColors.success : AppColors.faint, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _PersonSheet extends ConsumerWidget {
  const _PersonSheet({required this.id, required this.summary});
  final int id;
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(personProvider(id)).asData?.value ?? summary;
    final manager = d['manager'] is Map ? asMap(d['manager']) : null;
    final departments = (d['departments'] as List?)?.whereType<String>().join(', ');

    Widget row(IconData icon, String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(icon, size: 19, color: AppColors.faint),
              const SizedBox(width: 12),
              SizedBox(width: 88, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            ]),
          );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PersonAvatar(person: d, size: 72),
          const SizedBox(height: 12),
          Text(d['name'] as String? ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(d['job_title'] as String? ?? '', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          if ((d['motto'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text('"${d['motto']}"', textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.muted)),
          ],
          const SizedBox(height: 20),
          row(Icons.apartment_outlined, 'Divisi', departments?.isNotEmpty == true ? departments : d['department'] as String?),
          row(Icons.place_outlined, 'Lokasi', d['branch'] as String?),
          row(Icons.supervisor_account_outlined, 'Atasan', manager?['name'] as String?),
          row(Icons.event_outlined, 'Bergabung', _joined(d['joined'] as String?)),
        ]),
      ),
    );
  }

  static String? _joined(String? ym) {
    final d = ym == null ? null : DateTime.tryParse('$ym-01');
    return d == null ? null : '${monthLong(d)} ${d.year}';
  }
}
