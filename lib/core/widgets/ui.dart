import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Latar abu muda dengan pola titik halus (sama seperti tablet & web).
class DotBackground extends StatelessWidget {
  const DotBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: CustomPaint(painter: const _DotPainter(), child: child),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  static const _gap = 21.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.dot;
    for (var y = _gap / 2; y < size.height; y += _gap) {
      for (var x = _gap / 2; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => false;
}

/// Kerangka layar tab: latar bertitik + SafeArea + konten.
class DotScaffold extends StatelessWidget {
  const DotScaffold({super.key, required this.child, this.bottom});

  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: bottom,
      body: DotBackground(child: SafeArea(bottom: false, child: child)),
    );
  }
}

/// Latar navy di bagian atas (dipakai layar Masuk).
class GradientHeaderBackground extends StatelessWidget {
  const GradientHeaderBackground({super.key, required this.height, this.radius = 32});

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
          child: const Stack(children: [Positioned(top: -90, right: -70, child: YellowRing(size: 240))]),
        ),
      ),
    );
  }
}

/// Cincin kuning samar di pojok kartu navy.
class YellowRing extends StatelessWidget {
  const YellowRing({super.key, this.size = 160, this.width = 18});

  final double size;
  final double width;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withValues(alpha: .35), width: width),
          ),
        ),
      );
}

/// Kartu navy utama (hero) dengan cincin kuning di kanan atas.
class NavyHeroCard extends StatelessWidget {
  const NavyHeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.heroShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          const Positioned(top: -60, right: -50, child: YellowRing(size: 170, width: 16)),
          Padding(padding: padding, child: child),
        ]),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

/// Kartu putih bergaris tipis dengan bayangan lembut.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 16, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Material sendiri (bukan sekadar Container putih) supaya Ink/InkWell di
    // dalam kartu dilukis di atas kartu, bukan tertutup olehnya.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.line),
    );
    final box = DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: AppColors.cardShadow),
      child: Material(
        color: Colors.white,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

/// Judul layar tab: judul besar, subjudul abu, dan aksi di kanan.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 0)});

  final EdgeInsetsGeometry padding;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.4, color: AppColors.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Tombol ikon putih bergaris (lonceng, kalender, dsb.).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.badge = false});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, size: 21, color: AppColors.ink),
            if (badge)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Pilihan segmen (mis. Riwayat / Jadwal saya).
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                      color: i == index ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

enum PillTone { success, warning, danger, neutral, info, onPrimary, primary, accent }

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
      PillTone.warning => (AppColors.accentSoft, AppColors.accentText),
      PillTone.danger => (AppColors.dangerSoft, AppColors.danger),
      PillTone.info => (AppColors.infoSoft, AppColors.info),
      PillTone.neutral => (AppColors.chip, AppColors.chipText),
      PillTone.onPrimary => (Colors.white.withValues(alpha: 0.14), Colors.white),
      PillTone.primary => (AppColors.navySoft, AppColors.navy),
      PillTone.accent => (AppColors.accent, AppColors.navy),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
      ]),
    );
  }
}

/// Lingkaran ikon besar untuk layar hasil/kosong.
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
