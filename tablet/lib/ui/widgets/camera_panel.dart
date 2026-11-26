import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';

import '../../face/camera_service.dart';
import '../theme.dart';
import 'common.dart';

/// Panel kamera gelap dengan bingkai sudut dan label di atasnya.
class CameraPanel extends StatelessWidget {
  const CameraPanel({super.key, required this.camera, required this.bracket, this.topLeft, this.topRight, this.bottom});
  final CameraService camera;
  final Color bracket;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.navyDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x5516255A), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -12)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        ListenableBuilder(
          listenable: camera,
          builder: (context, _) {
            final c = camera.controller;
            if (camera.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(camera.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              );
            }
            if (c == null || !c.value.isInitialized) {
              return const Center(child: CircularProgressIndicator(color: C.yellow));
            }
            final ps = c.value.previewSize ?? const Size(640, 480);
            final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
            final size = portrait ? Size(ps.height, ps.width) : ps;
            return FittedBox(fit: BoxFit.cover, child: SizedBox(width: size.width, height: size.height, child: CameraPreview(c)));
          },
        ),
        CornerBrackets(color: bracket),
        if (topLeft != null) Positioned(left: 20, top: 20, child: topLeft!),
        if (topRight != null) Positioned(right: 20, top: 20, child: topRight!),
        if (bottom != null) Positioned(left: 0, right: 0, bottom: 28, child: Center(child: bottom!)),
      ]),
    );
  }
}

/// Label setengah transparan di atas kamera.
class GlassPill extends StatelessWidget {
  const GlassPill(this.text, {super.key, this.dot, this.icon, this.solid, this.solidText});
  final String text;
  final Color? dot;
  final IconData? icon;
  final Color? solid;
  final Color? solidText;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: solid ?? const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: solid == null ? Border.all(color: const Color(0x26FFFFFF)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 8)],
          if (icon != null) ...[Icon(icon, size: 15, color: solidText ?? Colors.white), const SizedBox(width: 8)],
          Text(text, style: TextStyle(color: solidText ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );
}

class HintCard extends StatelessWidget {
  const HintCard({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 12), spreadRadius: -8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: C.yellowSoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.person_outline, color: C.yellowText),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ]),
      );
}
