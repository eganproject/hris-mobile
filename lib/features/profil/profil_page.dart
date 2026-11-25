import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';

/// Tab Profil. Versi dasar (Tahap 1): identitas, HP absen terdaftar, keluar.
/// Menu atasan, data diri, struktur organisasi ditambahkan di Tahap 2.
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final e = user.employee;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primarySoft,
                child: Text(user.initials,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ),
            ),
            const SizedBox(height: 12),
            Text(e.fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              [e.jobPosition, if (e.number != null) 'NIK ${e.number}'].whereType<String>().join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
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
            const Text('Cahaya Optima Karya · HRIS', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.faint)),
          ],
        ),
      ),
    );
  }
}
