import 'package:material_ui/material_ui.dart';

/// Warna desain ulang (Ega, 26 Nov 2026), selaras dengan HRIS web & tablet:
/// navy utama, kuning sebagai aksen, latar abu muda bertitik.
class AppColors {
  static const navy = Color(0xFF16255A);
  static const navyDark = Color(0xFF0B1640);
  static const navyLight = Color(0xFF2A3C7A);
  static const navySoft = Color(0xFFEEF1F8);

  static const accent = Color(0xFFF9AE05);
  static const accentSoft = Color(0xFFFEF6E0);
  static const accentText = Color(0xFFB47A00);

  /// Nama lama dipertahankan agar layar lain tetap jalan; sekarang navy.
  static const primary = navy;
  static const primaryDark = navyDark;
  static const primarySoft = navySoft;
  static const logoDot = accent;

  static const background = Color(0xFFF3F5F9);
  static const dot = Color(0xFFDDE2EC);
  static const surface = Colors.white;
  static const ink = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const faint = Color(0xFF98A2B3);
  static const line = Color(0xFFEAECF0);
  static const inputLine = Color(0xFFD0D5DD);
  static const chip = Color(0xFFF2F4F7);
  static const chipText = Color(0xFF344054);

  static const success = Color(0xFF067647);
  static const successSoft = Color(0xFFECFDF3);
  static const info = Color(0xFF175CD3);
  static const infoSoft = Color(0xFFEFF8FF);
  static const warning = accentText;
  static const warningSoft = accentSoft;
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFEF3F2);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyLight, navy, navyDark],
    stops: [0, .5, 1],
  );

  static const navyGradient = headerGradient;

  /// Bayangan kartu putih: tipis dan lembut.
  static const cardShadow = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -12),
  ];

  /// Bayangan kartu navy utama.
  static const heroShadow = [
    BoxShadow(color: Color(0x9916255A), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -12),
  ];
}
