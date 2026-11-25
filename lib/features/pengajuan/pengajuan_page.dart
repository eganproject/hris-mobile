import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';

/// Tab Pengajuan (cuti, izin, lembur, tukar jadwal). Diisi di Tahap 2.
/// Koreksi absensi sudah tersedia (Tahap 1) lewat rute '/koreksi'.
class PengajuanPage extends StatelessWidget {
  const PengajuanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.edit_calendar_outlined, color: AppColors.primaryDark),
              ),
              title: const Text('Koreksi absensi', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Lupa absen atau jam salah'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/koreksi'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cuti, izin, lembur, dan tukar jadwal segera hadir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
