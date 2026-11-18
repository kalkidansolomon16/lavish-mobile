import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lavish design tokens — same as the web portal and the mobile design (mobile.css).
class C {
  static const bg = Color(0xFFF6F5F4);
  static const card = Colors.white;
  static const ink = Color(0xFF262626);
  static const muted = Color(0xFF808285);
  static const line = Color(0xFFE2E1DF);
  static const dark = Color(0xFF0A7379);
  static const tealDeep = Color(0xFF06565B);
  static const tealGlow = Color(0xFF12939A);
  static const tealNight = Color(0xFF06484C);
  static const gold = Color(0xFFCBA590);
  static const goldSoft = Color(0xFFF3E8E1);
  static const goldInk = Color(0xFF8A6249);
  static const mint = Color(0xFFD9E8E5);
  static const ok = Color(0xFF3F8A5F);
  static const okSoft = Color(0xFFE1F1E8);
  static const warn = Color(0xFFC78A1B);
  static const warnSoft = Color(0xFFFBEFD5);
  static const warnInk = Color(0xFF8A5F10);
  static const bad = Color(0xFFB8483F);
  static const badSoft = Color(0xFFF6DEDB);
  static const grey = Color(0xFFECEBE9);
  static const seg = Color(0xFFEAE9E6);
}

/// Serif headings (EB Garamond) and Roboto body text.
TextStyle serif(double size, {FontWeight weight = FontWeight.w600, Color? color, double? height}) =>
    GoogleFonts.ebGaramond(fontSize: size, fontWeight: weight, color: color ?? C.ink, height: height ?? 1.15);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.dark, primary: C.dark, secondary: C.gold, surface: C.bg),
    scaffoldBackgroundColor: C.bg,
  );
  final text = GoogleFonts.robotoTextTheme(base.textTheme).apply(bodyColor: C.ink, displayColor: C.ink);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serif(25),
    ),
    dividerColor: C.line,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: GoogleFonts.roboto(color: Colors.white, fontSize: 13.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      hintStyle: const TextStyle(color: C.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.dark, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.bad)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, showDragHandle: true),
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
  );
}

/// The teal header gradient used on Home, Welcome, Profile and Doctor screens.
const tealGradient = RadialGradient(
  center: Alignment(-0.7, -1.0),
  radius: 1.6,
  colors: [C.tealGlow, C.dark, C.tealDeep],
  stops: [0.0, 0.5, 1.0],
);
