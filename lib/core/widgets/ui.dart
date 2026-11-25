import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Latar oranye bergradasi dengan sudut bawah membulat dan dua lingkaran
/// samar, seperti di mockup.
class GradientHeaderBackground extends StatelessWidget {
  const GradientHeaderBackground({super.key, required this.height, this.radius = 36});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: Stack(children: [
            Positioned(
              top: -110,
              right: -80,
              child: _circle(260, 0.11),
            ),
            Positioned(
              top: 120,
              left: -70,
              child: _circle(160, 0.09),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: opacity), shape: BoxShape.circle),
      );
}

/// Kartu putih membulat dengan bayangan lembut.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // Material sendiri (bukan sekadar Container putih) supaya Ink/InkWell di dalam
    // kartu dilukis DI ATAS kartu. Tanpa ini tombol berlatar Ink (mis. "Absen
    // Pulang" di Beranda) terlukis di Material Scaffold, tertutup kartu, dan
    // tidak terlihat.
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: AppColors.cardShadow),
      child: Material(
        color: Colors.white,
        borderRadius: shape,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum PillTone { success, warning, danger, neutral, onPrimary, primary }

/// Label kecil membulat (status).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.success => (AppColors.successSoft, AppColors.success),
      PillTone.warning => (const Color(0xFFFFEDD5), AppColors.warning),
      PillTone.danger => (AppColors.dangerSoft, AppColors.danger),
      PillTone.neutral => (AppColors.chip, AppColors.muted),
      PillTone.onPrimary => (Colors.white.withValues(alpha: 0.2), Colors.white),
      PillTone.primary => (AppColors.primarySoft, AppColors.primaryDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 5)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ]),
    );
  }
}

/// Layar hasil penuh (berhasil, ditolak, tersimpan offline, dsb.).
class ResultIllustration extends StatelessWidget {
  const ResultIllustration({super.key, required this.icon, required this.color, required this.background});

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: background.withValues(alpha: 0.35), spreadRadius: 14),
          BoxShadow(color: background.withValues(alpha: 0.2), spreadRadius: 30),
        ],
      ),
      child: Icon(icon, size: 48, color: color),
    );
  }
}

/// Placeholder untuk tab/fitur yang dikerjakan di Tahap 2.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ResultIllustration(icon: icon, color: AppColors.primaryDark, background: AppColors.primarySoft),
            const SizedBox(height: 36),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.5)),
          ]),
        ),
      ),
    );
  }
}
