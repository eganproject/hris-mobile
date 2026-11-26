import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/t2_ui.dart';
import 'profil_providers.dart';

/// Tab Profil: identitas, menu akun, dan keluar. Menu atasan ada di tab Tim.
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final e = user.employee;
    final p = ref.watch(profileProvider).asData?.value;
    final isLeader = (p?['is_leader'] as bool?) ?? user.isLeader;

    return DotScaffold(
      child: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () async => ref.invalidate(profileProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
          children: [
            const TabHeader(title: 'Profil', padding: EdgeInsets.only(top: 12)),
            const SizedBox(height: 16),
            NavyHeroCard(
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.accent,
                  foregroundImage: e.photoUrl != null ? NetworkImage(e.photoUrl!) : null,
                  child: Text(user.initials,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (e.jobPosition != null)
                      Text(e.jobPosition!, style: const TextStyle(fontSize: 13, color: Color(0xCCFFFFFF))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (e.number != null) StatusPill(label: 'NIK ${e.number}', tone: PillTone.onPrimary),
                      if (e.branchName != null) StatusPill(label: e.branchName!, tone: PillTone.onPrimary),
                      if (isLeader) const StatusPill(label: 'Atasan', tone: PillTone.accent),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            const _GroupLabel('AKUN'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                _MenuRow(
                  icon: Icons.badge_outlined,
                  title: 'Data diri',
                  subtitle: 'Telepon, alamat, motto',
                  onTap: () => context.push('/profil/data-diri'),
                ),
                _MenuRow(
                  icon: Icons.account_tree_outlined,
                  title: 'Struktur organisasi',
                  subtitle: [e.department, e.managerName == null ? null : 'Atasan: ${e.managerName}'].whereType<String>().join(' · '),
                  onTap: () => context.push('/struktur'),
                ),
                if (isLeader)
                  _MenuRow(
                    icon: Icons.people_alt_outlined,
                    title: 'Rekan kerja',
                    subtitle: 'Cari rekan di seluruh kantor',
                    onTap: () => context.push('/rekan'),
                  ),
                _MenuRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifikasi',
                  onTap: () => context.push('/notifikasi'),
                  last: true,
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 19, color: AppColors.navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Absen masuk dan pulang dilakukan di tablet kantor atau mesin gudang. Aplikasi ini bisa dipakai dari HP mana saja.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.chipText, height: 1.45),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: Color(0xFFFECDCA))),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar dari aplikasi?'),
                    content: const Text('Kamu bisa masuk lagi kapan saja, dari HP mana saja.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
                    ],
                  ),
                );
                if (ok == true) await ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Keluar'),
            ),
            const SizedBox(height: 16),
            const Text('Cahaya Optima Karya · HRIS',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.faint)),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.faint)),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.title, this.subtitle, required this.onTap, this.last = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.navySoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              if (subtitle?.isNotEmpty ?? false) Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: T2Colors.faint),
        ]),
      ),
    );
  }
}
