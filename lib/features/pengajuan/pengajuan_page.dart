import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../t2_common/async_body.dart';
import '../t2_common/t2_ui.dart';
import 'pengajuan_providers.dart';
import 'pengajuan_widgets.dart';

/// Tab "Pengajuan": saldo cuti, tombol ajukan baru, dan pengajuan terakhir.
class PengajuanPage extends ConsumerWidget {
  const PengajuanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(pengajuanSummaryProvider);

    return Scaffold(
      backgroundColor: T2Colors.bg,
      body: SafeArea(
        bottom: false,
        child: AsyncBody<Map<String, dynamic>>(
          value: summary,
          onRefresh: () async => ref.invalidate(pengajuanSummaryProvider),
          builder: (data) {
            final balances = (data['balances'] as List? ?? const []);
            final recent = (data['recent'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                PageTitle('Pengajuan',
                    trailing: IconButton(
                      tooltip: 'Jadwal saya',
                      onPressed: () => context.push('/jadwal'),
                      icon: const Icon(Icons.calendar_month_outlined, color: T2Colors.ink),
                    )),
                const SizedBox(height: 16),
                if (balances.isNotEmpty) _BalanceCard(Map<String, dynamic>.from(balances.first as Map)),
                const SizedBox(height: 20),
                const SectionLabel('Ajukan baru'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .98,
                    children: [
                      _NewTile('Cuti', 'cuti', () => context.push('/pengajuan/cuti?kategori=cuti')),
                      _NewTile('Izin', 'izin', () => context.push('/pengajuan/cuti?kategori=izin')),
                      _NewTile('Sakit', 'sakit', () => context.push('/pengajuan/cuti?kategori=sakit')),
                      _NewTile('Lembur', 'lembur', () => context.push('/pengajuan/lembur')),
                      _NewTile('Tukar jadwal', 'tukar', () => context.push('/pengajuan/tukar')),
                      _NewTile('Koreksi', 'koreksi', () => context.push('/koreksi')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionLabel('Terakhir diajukan', action: 'Lihat semua', onAction: () => context.push('/pengajuan/semua')),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const EmptyNote('Belum ada pengajuan.')
                else
                  for (final item in recent)
                    Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: PengajuanTile(item)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.b);
  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final quota = (b['quota'] as num? ?? 0).toInt();
    final remaining = (b['remaining'] as num? ?? 0).toInt();
    final used = (b['used'] as num? ?? 0).toInt();
    final pending = (b['pending_days'] as num? ?? 0).toInt();
    final ratio = quota == 0 ? 0.0 : (remaining / quota).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: T2Colors.gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x47EA7F06), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sisa ${(b['name'] ?? 'cuti').toString().toLowerCase()} ${b['year'] ?? ''}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text.rich(TextSpan(children: [
          TextSpan(text: '$remaining ', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
          TextSpan(text: 'dari $quota hari', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]), style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: ratio, minHeight: 8, color: Colors.white, backgroundColor: Colors.white24),
        ),
        const SizedBox(height: 8),
        Text('$used hari terpakai${pending > 0 ? ' · $pending hari menunggu persetujuan' : ''}',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }
}

class _NewTile extends StatelessWidget {
  const _NewTile(this.label, this.category, this.onTap);
  final String label;
  final String category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = categoryStyle(category);
    return T2Card(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(16)),
          child: Icon(s.icon, color: s.fg, size: 23),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
