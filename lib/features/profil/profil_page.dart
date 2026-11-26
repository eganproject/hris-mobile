import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/t2_ui.dart';
import 'profil_providers.dart';

/// Tab Profil: identitas, menu atasan (hanya bila punya bawahan), menu akun,
/// dan keluar.
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final e = user.employee;
    final profile = ref.watch(profileProvider);
    final p = profile.asData?.value;
    final isLeader = (p?['is_leader'] as bool?) ?? user.isLeader;
    final leader = p?['leader'] is Map ? Map<String, dynamic>.from(p!['leader'] as Map) : null;
    final pending = (leader?['pending_approvals'] as num?)?.toInt() ?? 0;
    final teamSize = (leader?['team_size'] as num?)?.toInt();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(profileProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(children: [
              const GradientHeaderBackground(height: 210),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white,
                      child: Text(user.initials,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    ),
                    const SizedBox(height: 12),
                    Text(e.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      [e.jobPosition, if (e.number != null) 'NIK ${e.number}'].whereType<String>().join(' · '),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 22),
                  ]),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (isLeader) ...[
                  const _GroupLabel('MENU ATASAN'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      _MenuRow(
                        icon: Icons.fact_check_outlined,
                        title: 'Persetujuan',
                        subtitle: 'Cuti, izin, sakit, dan lembur tim',
                        badge: pending > 0 ? '$pending' : null,
                        onTap: () => context.push('/tim/persetujuan'),
                      ),
                      _MenuRow(
                        icon: Icons.groups_2_outlined,
                        title: 'Tim hari ini',
                        subtitle: teamSize == null ? 'Siapa yang sudah masuk' : '$teamSize anggota tim',
                        onTap: () => context.push('/tim/hari-ini'),
                      ),
                      _MenuRow(
                        icon: Icons.calendar_view_week_outlined,
                        title: 'Atur jadwal tim',
                        subtitle: 'Susun dan terbitkan jadwal mingguan',
                        onTap: () => context.push('/tim/jadwal'),
                        last: true,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                ],
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
                      subtitle: 'Atasan langsung dan tim di bawah Anda',
                      onTap: () => context.push('/struktur'),
                    ),
                    _MenuRow(
                      icon: Icons.event_note_outlined,
                      title: 'Jadwal saya',
                      subtitle: 'Shift minggu ini dan konfirmasi',
                      onTap: () => context.push('/jadwal'),
                    ),
                    _MenuRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifikasi',
                      onTap: () => context.push('/notifikasi'),
                      last: true,
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                const SizedBox(height: 24),
                OutlinedButton.icon(
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
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar'),
                ),
                const SizedBox(height: 16),
                const Text('Cahaya Optima Karya · HRIS',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ]),
            ),
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
  const _MenuRow({required this.icon, required this.title, this.subtitle, this.badge, required this.onTap, this.last = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
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
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: AppColors.primaryDark, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(99)),
              child: Text(badge!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          const Icon(Icons.chevron_right, color: T2Colors.faint),
        ]),
      ),
    );
  }
}
