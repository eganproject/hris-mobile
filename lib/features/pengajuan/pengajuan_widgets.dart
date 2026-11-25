import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../t2_common/t2_api.dart';
import '../t2_common/t2_format.dart';
import '../t2_common/t2_ui.dart';
import 'pengajuan_providers.dart';

/// Ikon & warna per kategori pengajuan, sesuai mockup.
({IconData icon, Color bg, Color fg}) categoryStyle(String? category) {
  switch (category) {
    case 'izin':
      return (icon: Icons.back_hand_outlined, bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
    case 'sakit':
      return (icon: Icons.thermostat_outlined, bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
    case 'lembur':
      return (icon: Icons.nightlight_outlined, bg: const Color(0xFFE0E7FF), fg: const Color(0xFF4338CA));
    case 'tukar':
      return (icon: Icons.swap_horiz_rounded, bg: const Color(0xFFE0F2FE), fg: const Color(0xFF0369A1));
    case 'koreksi':
      return (icon: Icons.edit_note_rounded, bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9));
    default:
      return (icon: Icons.wb_sunny_outlined, bg: T2Colors.orangeSoft, fg: T2Colors.orangeText);
  }
}

String itemDateLabel(Map<String, dynamic> item) {
  switch (item['kind']) {
    case 'leave':
      return rangeLabel(item['start_date'], item['end_date']);
    case 'overtime':
      return '${dateLabel(item['work_date'])} · ${item['start_time']} – ${item['end_time']}';
    case 'swap':
      return item['partner_date'] != null
          ? '${dateLabel(item['requester_date'], year: false)} ⇄ ${dateLabel(item['partner_date'], year: false)}'
          : dateLabel(item['requester_date']);
    default:
      return dateLabel(item['work_date']);
  }
}

class PengajuanTile extends ConsumerWidget {
  const PengajuanTile(this.item, {super.key});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = categoryStyle(item['category'] as String?);
    return T2Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => PengajuanDetailSheet(item: item),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14)),
          child: Icon(s.icon, color: s.fg, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['title'] ?? '', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(itemDateLabel(item), style: const TextStyle(fontSize: 12.5, color: T2Colors.muted)),
          ]),
        ),
        StatusChip(item['status_label'] ?? '', tone: item['tone'] as String?),
      ]),
    );
  }
}

/// Rincian pengajuan + tombol batalkan / jawab permintaan tukar.
class PengajuanDetailSheet extends ConsumerStatefulWidget {
  const PengajuanDetailSheet({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  ConsumerState<PengajuanDetailSheet> createState() => _PengajuanDetailSheetState();
}

class _PengajuanDetailSheetState extends ConsumerState<PengajuanDetailSheet> {
  bool _busy = false;

  Future<void> _run(Future<Map<String, dynamic>> Function(T2Api api) action) async {
    setState(() => _busy = true);
    try {
      final res = await action(ref.read(t2ApiProvider));
      refreshPengajuan(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, (res['message'] ?? 'Berhasil.') as String);
    } catch (e) {
      if (mounted) showSnack(context, t2Error(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final kind = item['kind'];
    final rows = <(String, String?)>[
      ('Tanggal', itemDateLabel(item)),
      if (kind == 'swap') ('Rekan', (item['role'] == 'partner' ? item['requester'] : item['partner'])?['name'] as String?),
      ('Alasan', item['reason'] as String?),
      if (item['supervisor'] != null) ('Atasan', item['supervisor'] as String?),
      if (item['decision_notes'] != null) ('Catatan', item['decision_notes'] as String?),
      if (item['notes'] != null) ('Catatan', item['notes'] as String?),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: T2Colors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(item['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            StatusChip(item['status_label'] ?? '', tone: item['tone'] as String?),
          ]),
          const SizedBox(height: 12),
          for (final r in rows.where((r) => (r.$2 ?? '').isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 80, child: Text(r.$1, style: const TextStyle(color: T2Colors.muted, fontSize: 13))),
                Expanded(child: Text(r.$2!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              ]),
            ),
          const SizedBox(height: 8),
          if (item['can_respond'] == true)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
                  onPressed: _busy ? null : () => _run((api) => api.post('swaps/${item['id']}/respond', data: {'decision': 'reject'})),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Setujui',
                  busy: _busy,
                  onPressed: () => _run((api) => api.post('swaps/${item['id']}/respond', data: {'decision': 'accept'})),
                ),
              ),
            ])
          else if (item['can_cancel'] == true)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                  foregroundColor: const Color(0xFFB91C1C),
                ),
                onPressed: _busy
                    ? null
                    : () => _run((api) => switch (kind) {
                          'leave' => api.post('leave/${item['id']}/cancel'),
                          'overtime' => api.delete('overtime/${item['id']}'),
                          _ => api.delete('swaps/${item['id']}'),
                        }),
                child: const Text('Batalkan pengajuan'),
              ),
            ),
        ]),
      ),
    );
  }
}
