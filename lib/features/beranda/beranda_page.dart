import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../core/widgets/ui.dart';
import '../absen/attendance_models.dart';
import '../absen/attendance_repository.dart';

/// Beranda karyawan: jadwal dan jam masuk/pulang hari ini (hanya dibaca;
/// absen dilakukan di tablet kantor atau mesin gudang) plus jalan pintas.
class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final status = ref.watch(attendanceStatusProvider);
    final data = status.value;
    final now = DateTime.now();

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(attendanceStatusProvider);
          await ref.read(attendanceStatusProvider.future).catchError((_) => data!);
        },
        child: Stack(children: [
          const GradientHeaderBackground(height: 220),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _header(context, user?.initials ?? '', user?.firstName ?? '', now),
                const SizedBox(height: 24),
                if (status.hasError && data == null)
                  AppCard(child: Text(apiErrorMessage(status.error!), style: const TextStyle(color: AppColors.danger)))
                else
                  _todayCard(data, now),
                const SizedBox(height: 20),
                const Text('Ajukan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(children: [
                  _shortcut(context, Icons.wb_sunny_outlined, 'Cuti', '/pengajuan/cuti?kategori=cuti'),
                  _shortcut(context, Icons.medical_services_outlined, 'Izin/Sakit', '/pengajuan/cuti?kategori=izin'),
                  _shortcut(context, Icons.schedule, 'Lembur', '/pengajuan/lembur'),
                  _shortcut(context, Icons.swap_horiz, 'Tukar jadwal', '/pengajuan/tukar'),
                ]),
                if (user?.isLeader ?? false) ...[
                  const SizedBox(height: 20),
                  AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_outlined, color: AppColors.navy),
                      title: const Text('Persetujuan tim', style: TextStyle(fontWeight: FontWeight.w800)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/tim/persetujuan'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context, String initials, String firstName, DateTime now) => Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.greeting(now), style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13)),
            Text('Halo, $firstName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
        IconButton(
          tooltip: 'Notifikasi',
          onPressed: () => context.push('/notifikasi'),
          icon: const Icon(Icons.notifications_none, color: Colors.white),
        ),
      ]);

  Widget _todayCard(AttendanceStatusDto? data, DateTime now) {
    final day = data?.attendance;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Fmt.longDate(now), style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(data == null ? 'Memuat jadwal…' : data.shiftLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _timeBox('Masuk', day?.clockIn ?? data?.clockInAt)),
          const SizedBox(width: 10),
          Expanded(child: _timeBox('Pulang', day?.clockOut)),
        ]),
        const SizedBox(height: 12),
        const Text('Absen masuk dan pulang dilakukan di tablet kantor atau mesin absen.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
      ]),
    );
  }

  Widget _timeBox(String label, DateTime? at) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
          Text(Fmt.time(at),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: at == null ? AppColors.faint : AppColors.ink)),
        ]),
      );

  Widget _shortcut(BuildContext context, IconData icon, String label, String route) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
