import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../profil/profil_providers.dart';

/// Panel "Tim saya" di Beranda, hanya untuk atasan (punya bawahan).
/// Tiga pintasan: Persetujuan (dengan badge), Tim hari ini, Jadwal tim.
class LeaderPanel extends ConsumerWidget {
  const LeaderPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).asData?.value;
    final isLeader = (profile?['is_leader'] as bool?) ?? user?.isLeader ?? false;
    if (!isLeader) return const SizedBox.shrink();

    final leader = profile?['leader'] is Map ? Map<String, dynamic>.from(profile!['leader'] as Map) : null;
    final pending = (leader?['pending_approvals'] as num?)?.toInt() ?? 0;
    final teamSize = (leader?['team_size'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.groups_2_rounded, color: AppColors.navy, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Tim saya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (teamSize != null)
              Text('$teamSize orang', style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.fact_check_outlined,
                label: 'Persetujuan',
                badge: pending > 0 ? (pending > 99 ? '99+' : '$pending') : null,
                onTap: () => context.push('/tim/persetujuan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Shortcut(
                icon: Icons.how_to_reg_outlined,
                label: 'Tim hari ini',
                onTap: () => context.push('/tim/hari-ini'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Shortcut(
                icon: Icons.calendar_view_week_outlined,
                label: 'Jadwal tim',
                onTap: () => context.push('/tim/jadwal'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badge == null ? label : '$label, $badge menunggu',
      child: Material(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Icon(icon, color: AppColors.primaryDark, size: 26),
                if (badge != null)
                  Positioned(
                    right: -12,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(99)),
                      child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
