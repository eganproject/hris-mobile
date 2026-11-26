import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';

/// Warna bersama layar fitur. Nama "orange*" dipertahankan agar layar lama
/// tetap jalan, tetapi nilainya kini mengikuti desain baru (navy + kuning).
class T2Colors {
  static const orange = AppColors.navy;
  static const orangeLight = AppColors.navyLight;
  static const orangeDark = AppColors.navyDark;
  static const orangeSoft = AppColors.navySoft;
  static const orangeText = AppColors.navy;
  static const navy = AppColors.navy;
  static const accent = AppColors.accent;
  static const ink = AppColors.ink;
  static const muted = AppColors.muted;
  static const faint = AppColors.faint;
  static const bg = AppColors.background;
  static const line = AppColors.line;

  static const gradient = AppColors.headerGradient;
}

/// Warna chip status dari "tone" API (success / warning / danger / neutral / info).
({Color bg, Color fg}) toneColors(String? tone) {
  switch (tone) {
    case 'success':
      return (bg: AppColors.successSoft, fg: AppColors.success);
    case 'warning':
      return (bg: AppColors.accentSoft, fg: AppColors.accentText);
    case 'danger':
      return (bg: AppColors.dangerSoft, fg: AppColors.danger);
    case 'info':
    case 'accent':
      return (bg: AppColors.infoSoft, fg: AppColors.info);
    default:
      return (bg: AppColors.chip, fg: AppColors.chipText);
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.fg)),
    );
  }
}

class T2Card extends StatelessWidget {
  const T2Card({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.radius = 16, this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: AppColors.cardShadow),
      child: Material(
        color: color ?? Colors.white,
        shape: RoundedRectangleBorder(borderRadius: r, side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Alamat lengkap untuk berkas dari server. Server lama mengirim alamat foto
/// tanpa domain ("/storage/..."), yang tidak bisa dibuka aplikasi.
String? absoluteUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBaseUrl}${url.startsWith('/') ? '' : '/'}$url';
}

/// Lingkaran inisial navy dengan huruf kuning (atau foto bila ada).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 42, this.online, this.ringColor = Colors.white});
  final Map<String, dynamic>? person;
  final double size;

  /// true = titik hijau, false = titik abu-abu, null = tanpa titik.
  final bool? online;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final initials = (person?['initials'] ?? '?') as String;
    final photo = absoluteUrl(person?['photo_url'] as String?);
    // Foto di-decode seukuran avatar saja supaya daftar panjang tetap ringan.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.navy,
      foregroundImage: photo != null ? ResizeImage(NetworkImage(photo), width: px, height: px, policy: ResizeImagePolicy.fit) : null,
      onForegroundImageError: photo != null ? (_, _) {} : null,
      child: Text(initials, style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: size * .34)),
    );
    if (online == null) return avatar;
    final dot = (size * .3).clamp(10.0, 20.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: online! ? const Color(0xFF17B26A) : AppColors.inputLine,
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: dot * .2),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Konten dibatasi lebarnya di tablet/layar lebar supaya tetap enak dibaca.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 640});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child),
      );
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
        Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.4, color: T2Colors.ink))),
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
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T2Colors.ink))),
        if (action != null)
          GestureDetector(onTap: onAction, child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T2Colors.navy))),
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
  const BackHeader({super.key, required this.title, this.subtitle, this.trailing, this.showBack = true});
  final bool showBack;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(children: [
        if (showBack) ...[
          T2Card(
            radius: 12,
            padding: const EdgeInsets.all(9),
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.chevron_left, size: 22, color: T2Colors.ink),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.2, color: T2Colors.ink)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 13, color: T2Colors.muted)),
          ]),
        ),
        // Aksi di kanan mengecil di HP sempit alih-alih mendesak judul.
        if (trailing != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: trailing),
          ),
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
      height: 52,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Turunan dari tema supaya tetap memakai Inter (TextStyle polos jatuh ke font bawaan).
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                // Mengecil di HP sempit alih-alih terpotong/overflow.
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1))),
              ]),
      ),
    );
  }
}

/// Input putih bergaris tipis (gaya tema).
InputDecoration t2Input(String hint, {Widget? suffix}) => InputDecoration(hintText: hint, suffixIcon: suffix);

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.danger : T2Colors.navy,
    ));
}
