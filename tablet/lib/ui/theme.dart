import 'package:material_ui/material_ui.dart';

/// Warna dari mockup tablet (navy + kuning dari logo COK, latar abu bertitik).
class C {
  static const navy = Color(0xFF16255A);
  static const navyDark = Color(0xFF0B1530);
  static const yellow = Color(0xFFF9AE05);
  static const yellowSoft = Color(0xFFFEF6E0);
  static const yellowText = Color(0xFFB47A00);
  static const bg = Color(0xFFF3F5F9);
  static const dot = Color(0xFFDDE2EC);
  static const text = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFEAECF0);
  static const surface2 = Color(0xFFF9FAFB);
  static const green = Color(0xFF17B26A);
  static const greenSoft = Color(0xFFECFDF3);
  static const greenText = Color(0xFF067647);
  static const blue = Color(0xFF2E90FA);
  static const blueSoft = Color(0xFFEFF8FF);
  static const blueText = Color(0xFF175CD3);
  static const red = Color(0xFFF04438);
  static const redSoft = Color(0xFFFEF3F2);
  static const redText = Color(0xFFB42318);
  static const indigoSoft = Color(0xFFEEF2FF);
  static const indigoText = Color(0xFF3538CD);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.navy, primary: C.navy, secondary: C.yellow, surface: Colors.white),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.navy,
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF344054),
        minimumSize: const Size(56, 56),
        side: const BorderSide(color: Color(0xFFD0D5DD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.border)),
    ),
  );
}
