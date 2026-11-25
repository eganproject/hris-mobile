import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../t2_common/t2_ui.dart';
import 'profil_providers.dart';

/// Tab Profil: identitas, menu akun,
/// HP absen terdaftar, dan keluar. Menu atasan ada di Beranda (LeaderPanel).
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final e = user.employee;

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
                const _GroupLabel('HP ABSEN'),
                AppCard(
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.smartphone, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('HP absen terdaftar', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        Text(user.device?.model ?? 'HP ini', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ganti HP: cukup masuk dari HP baru, lalu tunggu persetujuan HR.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Keluar dari aplikasi?'),
                        content: const Text('Absen yang masih antre (belum terkirim) tetap tersimpan di HP ini.'),
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
          const Icon(Icons.chevron_right, color: T2Colors.faint),
        ]),
      ),
    );
  }
}
