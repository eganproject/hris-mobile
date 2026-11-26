import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/ui.dart';
import '../pengumuman/announcement_card.dart';
import '../pengumuman/pengumuman_page.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_ui.dart';
import 'rekan_view.dart';

/// Tab Info (karyawan): Pengumuman HR dan Rekan kerja.
class InfoPage extends StatefulWidget {
  const InfoPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  late int _tab = widget.initialTab;

  @override
  void didUpdateWidget(InfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return DotScaffold(
      child: Column(children: [
        const TabHeader(title: 'Info', subtitle: 'Kabar resmi dari HR dan rekan kerja'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: SegmentedTabs(labels: const ['Pengumuman HR', 'Rekan kerja'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        ),
        Expanded(child: IndexedStack(index: _tab, children: const [_AnnouncementList(), RekanView()])),
      ]),
    );
  }
}

/// Rekan kerja sebagai layar penuh (untuk atasan, yang tidak punya tab Info).
class RekanPage extends StatelessWidget {
  const RekanPage({super.key});

  @override
  Widget build(BuildContext context) => const DotScaffold(
        child: Column(children: [
          BackHeader(title: 'Rekan kerja'),
          SizedBox(height: 12),
          Expanded(child: RekanView(bottomPadding: 32)),
        ]),
      );
}

class _AnnouncementList extends ConsumerWidget {
  const _AnnouncementList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(announcementListProvider);
    return AsyncBody<List<Map<String, dynamic>>>(
      value: value,
      onRefresh: () async => ref.invalidate(announcementListProvider),
      builder: (items) => items.isEmpty
          ? ListView(children: const [EmptyNote('Belum ada pengumuman.', icon: Icons.campaign_outlined)])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => AnnouncementCard(item: items[i], onReturn: () => ref.invalidate(announcementListProvider)),
            ),
    );
  }
}
