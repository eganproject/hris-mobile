import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
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

    return DotScaffold(
      child: AsyncBody<Map<String, dynamic>>(
          value: summary,
          onRefresh: () async => ref.invalidate(pengajuanSummaryProvider),
          builder: (data) {
            final balances = (data['balances'] as List? ?? const []);
            final recent = (data['recent'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                TabHeader(
                  title: 'Pengajuan',
                  subtitle: 'Cuti, izin, sakit, lembur, dan tukar jadwal',
                  trailing: SquareIconButton(
                    icon: Icons.list_alt_rounded,
                    tooltip: 'Semua pengajuan saya',
                    onTap: () => context.push('/pengajuan/semua'),
                  ),
                ),
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
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.0,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NavyHeroCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sisa ${(b['name'] ?? 'cuti').toString().toLowerCase()} ${b['year'] ?? ''}',
              style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$remaining', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1)),
            TextSpan(text: ' / $quota hari', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xCCFFFFFF))),
          ]), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio, minHeight: 6, color: AppColors.accent, backgroundColor: Colors.white12),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            StatusPill(label: '$used hari terpakai', tone: PillTone.onPrimary),
            if (pending > 0) StatusPill(label: '$pending hari menunggu', tone: PillTone.accent),
          ]),
        ]),
      ),
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
      radius: 14,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(11)),
          child: Icon(s.icon, color: s.fg, size: 21),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
