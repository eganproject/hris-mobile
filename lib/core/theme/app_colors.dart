import 'package:material_ui/material_ui.dart';

/// Warna final (Ega, 25 Nov 2026): oranye utama, navy aksen.
class AppColors {
  static const primary = Color(0xFFEA7F06);
  static const primaryDark = Color(0xFF9A4A05);
  static const primarySoft = Color(0xFFFDEBD3);
  static const gradientStart = Color(0xFFFBB040);
  static const gradientEnd = Color(0xFFC2560A);
  static const navy = Color(0xFF16255A);
  static const navyLight = Color(0xFF3A5AA8);
  static const logoDot = Color(0xFFF5A623);

  static const background = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF0F1733);
  static const muted = Color(0xFF5B6478);
  static const faint = Color(0xFF98A1B5);
  static const line = Color(0xFFE5E9F2);
  static const chip = Color(0xFFEEF1F6);

  static const success = Color(0xFF166534);
  static const successSoft = Color(0xFFDCFCE7);
  static const warning = Color(0xFF9A3412);
  static const warningSoft = Color(0xFFFFF7ED);
  static const danger = Color(0xFFB91C1C);
  static const dangerSoft = Color(0xFFFEE2E2);

  static const headerGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [gradientStart, primary, gradientEnd],
    stops: [0, 0.45, 1],
  );

  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyLight, navy],
  );

  static const cardShadow = [
    BoxShadow(color: Color(0x14111C45), blurRadius: 30, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0A111C45), blurRadius: 6, offset: Offset(0, 2)),
  ];
}
