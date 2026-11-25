import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../t2_common/async_body.dart';
import '../t2_common/t2_ui.dart';
import 'pengajuan_providers.dart';
import 'pengajuan_widgets.dart';

/// Semua pengajuan milik sendiri, bisa disaring per jenis.
class PengajuanListPage extends ConsumerStatefulWidget {
  const PengajuanListPage({super.key});

  @override
  ConsumerState<PengajuanListPage> createState() => _PengajuanListPageState();
}

class _PengajuanListPageState extends ConsumerState<PengajuanListPage> {
  String? _type;

  static const _filters = <(String, String?)>[
    ('Semua', null),
    ('Cuti', 'cuti'),
    ('Izin', 'izin'),
    ('Sakit', 'sakit'),
    ('Lembur', 'lembur'),
    ('Tukar', 'tukar'),
    ('Koreksi', 'koreksi'),
  ];

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(pengajuanListProvider(_type));

    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        child: Column(children: [
          const BackHeader(title: 'Semua pengajuan'),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$1),
                      selected: _type == f.$2,
                      selectedColor: T2Colors.orangeSoft,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _type == f.$2 ? T2Colors.orangeText : T2Colors.muted),
                      onSelected: (_) => setState(() => _type = f.$2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncBody<List<Map<String, dynamic>>>(
              value: list,
              onRefresh: () async => ref.invalidate(pengajuanListProvider(_type)),
              builder: (items) => items.isEmpty
                  ? ListView(children: const [EmptyNote('Belum ada pengajuan.')])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => PengajuanTile(items[i]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
