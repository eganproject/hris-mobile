import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/async_body.dart';
import '../t2_common/auth_image.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

final announcementListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('announcements');
  return asList(res['data']);
});

final announcementProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ref.read(t2ApiProvider).get('announcements/$id');
  return asMap(res['data']);
});

/// Detail pengumuman + tombol "Saya sudah membaca" (tanda baca untuk HR).
class PengumumanDetailPage extends ConsumerStatefulWidget {
  const PengumumanDetailPage({super.key, required this.id});
  final int id;

  @override
  ConsumerState<PengumumanDetailPage> createState() => _PengumumanDetailPageState();
}

class _PengumumanDetailPageState extends ConsumerState<PengumumanDetailPage> {
  bool _busy = false;

  Future<void> _markRead() async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(t2ApiProvider).post('announcements/${widget.id}/read');
      ref.invalidate(announcementProvider(widget.id));
      if (mounted) showSnack(context, res['message'] as String? ?? 'Sudah ditandai dibaca.');
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(announcementProvider(widget.id));
    final a = value.asData?.value;
    final read = a?['is_read'] == true;

    return DotScaffold(
      child: SafeArea(
        child: Column(children: [
          const BackHeader(title: 'Pengumuman'),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: value,
              onRefresh: () async => ref.invalidate(announcementProvider(widget.id)),
              builder: (a) {
                final att = a['attachment'] is Map ? asMap(a['attachment']) : null;
                final isImage = (att?['mime'] as String?)?.startsWith('image/') ?? false;
                return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                  T2Card(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (a['is_pinned'] == true) const StatusChip('Disematkan', tone: 'warning'),
                        StatusChip(a['audience_label'] as String? ?? 'Semua karyawan', tone: 'info'),
                      ]),
                      const SizedBox(height: 12),
                      Text(a['title'] as String? ?? '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25, color: T2Colors.ink)),
                      const SizedBox(height: 6),
                      Text('${a['author']} · ${dateLabel(a['published_at'])}',
                          style: const TextStyle(fontSize: 13, color: T2Colors.muted)),
                      const Divider(height: 28, color: T2Colors.line),
                      SelectableText(a['body'] as String? ?? '', style: const TextStyle(fontSize: 15, height: 1.55, color: T2Colors.ink)),
                      if (att != null) ...[
                        const SizedBox(height: 16),
                        if (isImage)
                          AuthImage('announcements/${a['id']}/attachment', height: 240)
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: T2Colors.bg, borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              const Icon(Icons.description_outlined, color: T2Colors.navy),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(att['name'] as String? ?? 'Lampiran', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const Text('Buka lampiran ini dari HRIS web.', style: TextStyle(fontSize: 12, color: T2Colors.muted)),
                                ]),
                              ),
                            ]),
                          ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${a['read_count'] ?? 0} dari ${a['audience_count'] ?? 0} karyawan sudah membaca',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: T2Colors.muted),
                  ),
                ]);
              },
            ),
          ),
          if (a != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: read
                  ? Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'Sudah dibaca${a['read_at'] != null ? ' · ${dateLabel(a['read_at'], year: false)}' : ''}',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                      ),
                    )
                  : PrimaryButton(label: 'Saya sudah membaca', icon: Icons.done_all, busy: _busy, onPressed: _markRead),
            ),
        ]),
      ),
    );
  }
}
