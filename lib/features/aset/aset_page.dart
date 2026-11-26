import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/async_body.dart';
import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';

/// Daftar aset milik pengguna: {open[], history[], counts{open, unacknowledged, overdue}}.
final myAssetsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(t2ApiProvider).get('assets');
  return asMap(res['data']);
});

/// Konfirmasi terima aset. Mengembalikan true bila berhasil.
Future<bool> acknowledgeAsset(BuildContext context, WidgetRef ref, int id, {String? note}) async {
  try {
    final res = await ref.read(t2ApiProvider).post('assets/$id/acknowledge', data: {if (note != null && note.isNotEmpty) 'note': note});
    ref.invalidate(myAssetsProvider);
    if (context.mounted) showSnack(context, (res['message'] ?? 'Penerimaan aset sudah dikonfirmasi.') as String);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, t2Error(e), error: true);
    return false;
  }
}

/// Lembar "Ada masalah": catatan kondisi lalu konfirmasi terima dengan catatan itu.
Future<bool> showAssetProblemSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> row) async {
  final asset = asMap(row['asset']);
  final note = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => _ProblemSheet(assetName: asset['name'] as String? ?? 'Aset'),
  );
  if (note == null || !context.mounted) return false;
  return acknowledgeAsset(context, ref, (row['id'] as num).toInt(), note: note);
}

class AsetPage extends ConsumerWidget {
  const AsetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myAssetsProvider);

    return DotScaffold(
      child: Column(
        children: [
          const BackHeader(title: 'Aset saya', subtitle: 'Barang kantor yang tercatat atas namamu'),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<Map<String, dynamic>>(
              value: data,
              onRefresh: () async => ref.invalidate(myAssetsProvider),
              builder: (d) {
                final open = asList(d['open']);
                final history = asList(d['history']);
                final counts = asMap(d['counts']);
                final pending = open.where((r) => r['state'] == 'unacknowledged').toList();
                final held = open.where((r) => r['state'] != 'unacknowledged').toList();
                final overdue = (counts['overdue'] as num?)?.toInt() ?? 0;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  children: [
                    MaxWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NavyHeroCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Sedang kamu pegang',
                                        style: TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF), fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 4),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${open.length}',
                                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                                            ),
                                            const TextSpan(
                                              text: ' aset',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xCCFFFFFF)),
                                            ),
                                          ],
                                        ),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      if (pending.isNotEmpty || overdue > 0) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            if (pending.isNotEmpty)
                                              StatusPill(label: '${pending.length} perlu dikonfirmasi', tone: PillTone.accent),
                                            if (overdue > 0) StatusPill(label: '$overdue lewat tanggal kembali', tone: PillTone.onPrimary),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(14)),
                                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.accent, size: 26),
                                ),
                              ],
                            ),
                          ),
                          for (final r in pending) ...[const SizedBox(height: 12), PendingAssetCard(row: r)],
                          const SizedBox(height: 22),
                          if (open.isEmpty && history.isEmpty)
                            const EmptyNote('Belum ada aset kantor yang tercatat atas namamu.', icon: Icons.inventory_2_outlined),
                          if (held.isNotEmpty) ...[
                            const _Label('SEDANG DIPEGANG'),
                            AppCard(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [for (final (i, r) in held.indexed) _AssetRow(row: r, last: i == held.length - 1)],
                              ),
                            ),
                            const SizedBox(height: 22),
                          ],
                          if (history.isNotEmpty) ...[
                            const _Label('PERNAH DIPEGANG'),
                            AppCard(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [for (final (i, r) in history.indexed) _AssetRow(row: r, last: i == history.length - 1)],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: .6),
    ),
  );
}

String assetSubtitle(Map<String, dynamic> asset) => [
  asset['code'],
  asset['category'],
  [asset['brand'], asset['model']].whereType<String>().join(' '),
].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

/// Kartu aset yang menunggu konfirmasi terima (garis kuning di kiri).
class PendingAssetCard extends ConsumerStatefulWidget {
  const PendingAssetCard({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  ConsumerState<PendingAssetCard> createState() => _PendingAssetCardState();
}

class _PendingAssetCardState extends ConsumerState<PendingAssetCard> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final asset = asMap(row['asset']);
    final id = (row['id'] as num).toInt();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: AppColors.accent)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(child: StatusChip('Perlu dikonfirmasi', tone: 'warning')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shortDate(row['assigned_at']),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.faint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(asset['name'] as String? ?? '-', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                Text(assetSubtitle(asset), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                const SizedBox(height: 8),
                Text(
                  [
                    if (row['assigned_by'] != null) 'Diserahkan oleh ${row['assigned_by']}',
                    if (row['condition_out'] != null && row['condition_out'] != '-')
                      'kondisi ${(row['condition_out'] as String).toLowerCase()}',
                  ].join(', '),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.chipText),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: _busy ? null : () => _run(() => showAssetProblemSheet(context, ref, row)),
                        child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Ada masalah')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _busy ? null : () => _run(() => acknowledgeAsset(context, ref, id)),
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const FittedBox(fit: BoxFit.scaleDown, child: Text('Konfirmasi terima')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.row, required this.last});
  final Map<String, dynamic> row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final asset = asMap(row['asset']);
    final state = row['state'] as String?;
    final (chip, tone) = switch (state) {
      'overdue' => ('Lewat tanggal', 'danger'),
      'returned' => ('Dikembalikan', 'neutral'),
      'unacknowledged' => ('Perlu dikonfirmasi', 'warning'),
      _ => ('Dipegang', 'success'),
    };
    final when = state == 'returned'
        ? '${shortDate(row['assigned_at'])} – ${shortDate(row['returned_at'])}'
        : row['expected_return_at'] != null
        ? 'Kembali ${shortDate(row['expected_return_at'])}'
        : 'Sejak ${shortDate(row['assigned_at'])}';
    return InkWell(
      onTap: () => showAssetDetail(context, row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: state == 'returned' ? AppColors.chip : AppColors.navySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_outlined, size: 20, color: state == 'returned' ? AppColors.muted : AppColors.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset['name'] as String? ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    [asset['code'], when].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(chip, tone: tone),
          ],
        ),
      ),
    );
  }
}

/// Rincian satu masa pegang aset.
void showAssetDetail(BuildContext context, Map<String, dynamic> row) {
  final asset = asMap(row['asset']);
  final lines = <(String, String?)>[
    ('Kode', asset['code'] as String?),
    ('Kategori', asset['category'] as String?),
    ('Merek / model', [asset['brand'], asset['model']].whereType<String>().join(' ')),
    ('No. seri', asset['serial_number'] as String?),
    ('Diserahkan', [dateLabel(row['assigned_at']), if (row['assigned_by'] != null) 'oleh ${row['assigned_by']}'].join(' ')),
    ('Kondisi saat terima', row['condition_out'] as String?),
    ('Keperluan', row['purpose'] as String?),
    ('Tanggal kembali', row['expected_return_at'] == null ? null : dateLabel(row['expected_return_at'])),
    ('Dikonfirmasi', row['acknowledged_at'] == null ? null : dateLabel(row['acknowledged_at'])),
    ('Catatanmu', row['acknowledgement_note'] as String?),
    ('Dikembalikan', row['returned_at'] == null ? null : dateLabel(row['returned_at'])),
    ('Kondisi saat kembali', row['condition_in'] as String?),
    ('Catatan', row['notes'] as String?),
  ].where((l) => l.$2 != null && l.$2!.trim().isNotEmpty && l.$2 != '-').toList();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        child: MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(asset['name'] as String? ?? 'Aset', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(l.$1, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ),
                      Expanded(
                        child: Text(l.$2!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProblemSheet extends StatefulWidget {
  const _ProblemSheet({required this.assetName});
  final String assetName;

  @override
  State<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends State<_ProblemSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: MaxWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ada masalah dengan ${widget.assetName}?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Tulis kondisinya, misalnya lecet atau kelengkapan kurang. Catatan ini ikut tersimpan saat kamu mengonfirmasi penerimaan.',
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              autofocus: true,
              maxLines: 4,
              maxLength: 500,
              decoration: t2Input('Contoh: layar ada goresan di pojok kanan'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Konfirmasi dengan catatan',
              onPressed: _note.text.trim().isEmpty ? null : () => Navigator.pop(context, _note.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}
