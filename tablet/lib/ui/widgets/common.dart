import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/tablet_controller.dart';
import '../theme.dart';

/// Latar abu bertitik seperti mockup.
class DottedBackground extends StatelessWidget {
  const DottedBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotPainter(), child: child);
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = C.bg);
    final p = Paint()..color = C.dot;
    for (double y = 11; y < size.height; y += 22) {
      for (double x = 11; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = C.greenSoft, this.fg = C.greenText, this.dot, this.icon, this.border});
  final String text;
  final Color bg;
  final Color fg;
  final Color? dot;
  final IconData? icon;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: border == null ? null : Border.all(color: border!)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 8)],
          Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Kepala layar: logo, nama perusahaan, lokasi, status online/antrean, tanggal.
class TabletHeader extends StatelessWidget {
  const TabletHeader({super.key, required this.tablet, this.onLock, this.subtitle});
  final TabletController tablet;
  final VoidCallback? onLock;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final d = tablet.data;
    final queue = tablet.queueCount;
    final status = tablet.online
        ? Pill(queue > 0 ? 'Online · $queue antre' : 'Online', dot: C.green)
        : Pill(queue > 0 ? 'Offline · $queue antre' : 'Offline', bg: C.yellowSoft, fg: C.yellowText, dot: C.yellow);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.border))),
      child: Row(children: [
        Image.asset('assets/img/logo.png', width: 42, height: 42),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d?.company ?? 'Cahaya Optima Karya', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.navy)),
          Text(subtitle ?? 'Absensi wajah${d == null ? '' : ' · ${d.branchName}'}', style: const TextStyle(fontSize: 13, color: C.muted)),
        ]),
        const Spacer(),
        status,
        const SizedBox(width: 10),
        Pill(DateFormat('EEEE, d MMMM y', 'id_ID').format(DateTime.now()), bg: Colors.white, fg: const Color(0xFF344054), icon: Icons.calendar_today_outlined, border: C.border),
        if (onLock != null) ...[
          const SizedBox(width: 10),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onLock,
              child: const SizedBox(width: 44, height: 44, child: Icon(Icons.lock_outline, size: 20, color: Color(0xFF344054), semanticLabel: 'Menu HR')),
            ),
          ),
        ],
      ]),
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.color = Colors.white});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.border),
          boxShadow: const [BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -12)],
        ),
        child: child,
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 38, this.bg = C.indigoSoft, this.fg = C.indigoText, this.border = false});
  final String initials;
  final double size;
  final Color bg;
  final Color fg;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: border ? Border.all(color: Colors.white, width: 4) : null),
        child: Text(initials, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.32)),
      );
}

/// Sudut bingkai kuning/hijau/merah di atas kamera.
class CornerBrackets extends StatelessWidget {
  const CornerBrackets({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _BracketPainter(color), size: Size.infinite));
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.46, h = size.height * 0.6;
    final l = (size.width - w) / 2, t = (size.height - h) / 2 - size.height * 0.04;
    final r = l + w, b = t + h;
    const len = 40.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(l, t + len)..lineTo(l, t)..lineTo(l + len, t), p);
    canvas.drawPath(Path()..moveTo(r - len, t)..lineTo(r, t)..lineTo(r, t + len), p);
    canvas.drawPath(Path()..moveTo(l, b - len)..lineTo(l, b)..lineTo(l + len, b), p);
    canvas.drawPath(Path()..moveTo(r - len, b)..lineTo(r, b)..lineTo(r, b - len), p);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) => old.color != color;
}

/// Papan angka untuk PIN.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.length, required this.value, required this.onChanged, required this.onSubmit, this.submitLabel = 'Masuk'});
  final int length;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Color? bg, Color? fg}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: bg ?? C.surface2,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: SizedBox(height: 60, child: Center(child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg ?? C.text)))),
              ),
            ),
          ),
        );

    void add(String d) {
      if (value.length < length) onChanged(value + d);
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < length; i++)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < value.length ? C.navy : Colors.white, border: Border.all(color: i < value.length ? C.navy : const Color(0xFFD0D5DD), width: 2)),
          ),
      ]),
      const SizedBox(height: 20),
      for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
        Row(children: [for (final d in row) key(d, onTap: () => add(d))]),
      Row(children: [
        key('Hapus', onTap: value.isEmpty ? null : () => onChanged(value.substring(0, value.length - 1)), fg: C.muted),
        key('0', onTap: () => add('0')),
        key(submitLabel, onTap: value.length == length ? onSubmit : null, bg: value.length == length ? C.navy : const Color(0xFFD0D5DD), fg: Colors.white),
      ]),
    ]);
  }
}

/// Jam berjalan (diperbarui tiap detik).
class LiveClock extends StatefulWidget {
  const LiveClock({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late Timer _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

String greeting(DateTime now) => switch (now.hour) {
      < 11 => 'Selamat pagi',
      < 15 => 'Selamat siang',
      < 18 => 'Selamat sore',
      _ => 'Selamat malam',
    };

String hm(DateTime t) => DateFormat('HH:mm').format(t);
