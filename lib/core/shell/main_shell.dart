import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/profil/profil_providers.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';

/// Urutan cabang di router (lihat app_router.dart).
abstract final class ShellTab {
  static const beranda = 0;
  static const kehadiran = 1;
  static const pengajuan = 2;
  static const info = 3;
  static const tim = 4;
  static const profil = 5;
}

typedef _Item = (int branch, IconData icon, IconData activeIcon, String label);

/// Kerangka dengan menu bawah. Karyawan: Beranda · Kehadiran · Pengajuan ·
/// Info · Profil. Atasan (punya bawahan): Info diganti Tim (dengan badge
/// jumlah persetujuan yang menunggu).
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _beranda = (ShellTab.beranda, Icons.home_outlined, Icons.home_rounded, 'Beranda');
  static const _kehadiran = (ShellTab.kehadiran, Icons.calendar_month_outlined, Icons.calendar_month, 'Kehadiran');
  static const _pengajuan = (ShellTab.pengajuan, Icons.description_outlined, Icons.description, 'Pengajuan');
  static const _info = (ShellTab.info, Icons.campaign_outlined, Icons.campaign, 'Info');
  static const _tim = (ShellTab.tim, Icons.groups_outlined, Icons.groups, 'Tim');
  static const _profil = (ShellTab.profil, Icons.person_outline, Icons.person, 'Profil');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = user?.isLeader == true ? ref.watch(profileProvider).asData?.value : null;
    final isLeader = (profile?['is_leader'] as bool?) ?? user?.isLeader ?? false;
    final leader = profile?['leader'];
    final pending = leader is Map ? (leader['pending_approvals'] as num?)?.toInt() ?? 0 : 0;

    final List<_Item> items = [_beranda, _kehadiran, _pengajuan, isLeader ? _tim : _info, _profil];

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
            boxShadow: const [BoxShadow(color: Color(0x1F101828), blurRadius: 30, offset: Offset(0, 12), spreadRadius: -10)],
          ),
          child: Row(children: [
            for (final item in items)
              Expanded(child: _item(item, badge: item.$1 == ShellTab.tim && pending > 0 ? pending : null)),
          ]),
        ),
      ),
    );
  }

  Widget _item(_Item item, {int? badge}) {
    final (branch, icon, activeIcon, label) = item;
    final active = shell.currentIndex == branch;
    return Semantics(
      label: badge == null ? label : '$label, $badge menunggu',
      selected: active,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => shell.goBranch(branch, initialLocation: branch == shell.currentIndex),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 28,
              decoration: BoxDecoration(
                color: active ? AppColors.navy : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Icon(active ? activeIcon : icon, size: 20, color: active ? Colors.white : AppColors.faint),
            ),
            if (badge != null)
              Positioned(
                top: -5,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text('$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.navy)),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.navy : AppColors.faint,
              )),
        ]),
      ),
    );
  }
}
