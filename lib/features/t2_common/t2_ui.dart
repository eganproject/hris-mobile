import 'package:material_ui/material_ui.dart';

/// Warna & komponen kecil bersama layar Tahap 2, mengikuti mockup
/// (oranye utama #EA7F06, navy #16255A sebagai aksen, kartu bulat).
class T2Colors {
  static const orange = Color(0xFFEA7F06);
  static const orangeLight = Color(0xFFFBB040);
  static const orangeDark = Color(0xFFC2560A);
  static const orangeSoft = Color(0xFFFDEBD3);
  static const orangeText = Color(0xFF9A4A05);
  static const navy = Color(0xFF16255A);
  static const ink = Color(0xFF0F1733);
  static const muted = Color(0xFF5B6478);
  static const faint = Color(0xFF8A93A8);
  static const bg = Color(0xFFF4F6FA);
  static const line = Color(0xFFE5E9F2);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orangeLight, orange, orangeDark],
    stops: [0, .45, 1],
  );
}

/// Warna chip status dari "tone" API (success / warning / danger / neutral / info).
({Color bg, Color fg}) toneColors(String? tone) {
  switch (tone) {
    case 'success':
      return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
    case 'warning':
      return (bg: const Color(0xFFFFEDD5), fg: const Color(0xFF9A3412));
    case 'danger':
      return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
    case 'info':
      return (bg: const Color(0xFFE0F2FE), fg: const Color(0xFF0369A1));
    case 'accent':
      return (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9));
    default:
      return (bg: const Color(0xFFF1F3F7), fg: T2Colors.muted);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone});
  final String label;
  final String? tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.fg)),
    );
  }
}

class T2Card extends StatelessWidget {
  const T2Card({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.radius = 20, this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x14111C45), blurRadius: 30, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x0A111C45), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

/// Lingkaran inisial (atau foto bila ada).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 42});
  final Map<String, dynamic>? person;
  final double size;

  static const _palette = [Color(0xFFF59E0B), Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFEF4444), Color(0xFF0EA5E9), Color(0xFF8B5CF6)];

  @override
  Widget build(BuildContext context) {
    final name = (person?['name'] ?? '?') as String;
    final initials = (person?['initials'] ?? '?') as String;
    final photo = person?['photo_url'] as String?;
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      foregroundImage: photo != null ? NetworkImage(photo) : null,
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .36)),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.4, color: T2Colors.ink))),
        ?trailing,
      ]),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T2Colors.ink))),
        if (action != null)
          GestureDetector(onTap: onAction, child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T2Colors.orangeText))),
      ]),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 40, color: T2Colors.faint),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: T2Colors.muted, fontSize: 14)),
      ]),
    );
  }
}

/// Header layar sekunder: tombol kembali bulat + judul + subjudul.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(children: [
        T2Card(
          radius: 22,
          padding: const EdgeInsets.all(10),
          onTap: () => Navigator.of(context).maybePop(),
          child: const Icon(Icons.chevron_left, size: 24, color: T2Colors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: T2Colors.ink)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 13, color: T2Colors.muted)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: T2Colors.orange,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Text(label),
              ]),
      ),
    );
  }
}

/// Input berlatar abu bulat seperti mockup.
InputDecoration t2Input(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: T2Colors.bg,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB91C1C) : T2Colors.navy,
    ));
}
