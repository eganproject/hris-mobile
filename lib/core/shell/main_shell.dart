import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Kerangka dengan menu bawah melayang (sesuai mockup):
/// Beranda, Riwayat, Pengajuan, Info (pengumuman HR), Profil.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Riwayat'),
    (Icons.description_outlined, Icons.description, 'Pengajuan'),
    (Icons.campaign_outlined, Icons.campaign, 'Info'),
    (Icons.person_outline, Icons.person, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [BoxShadow(color: Color(0x24111C45), blurRadius: 32, offset: Offset(0, 12))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _items.length; i++) _item(context, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index) {
    final (icon, activeIcon, label) = _items[index];
    final active = shell.currentIndex == index;
    return Semantics(
      label: label,
      selected: active,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: active ? 16 : 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(children: [
            Icon(active ? activeIcon : icon, size: 22, color: active ? AppColors.primaryDark : const Color(0xFF8A93A8)),
            if (active) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            ],
          ]),
        ),
      ),
    );
  }
}
