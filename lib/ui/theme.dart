import 'package:flutter/material.dart';

/// Warm brown & butter palette.
class AppColors {
  static const cream = Color(0xFFFBF6EC);
  static const paper = Color(0xFFFFFDF7);
  static const line = Color(0xFFEADFC8);
  static const lineStrong = Color(0xFFD9C7A3);
  static const butter50 = Color(0xFFFFF8E6);
  static const butter100 = Color(0xFFFBEFC8);
  static const butter200 = Color(0xFFF6E2A3);
  static const butter300 = Color(0xFFF3D98B);
  static const butter400 = Color(0xFFE9C46A);
  static const caramel = Color(0xFFB9824A);
  static const brown400 = Color(0xFF8A5D3B);
  static const brown600 = Color(0xFF5B3A29);
  static const brown700 = Color(0xFF462C1F);
  static const espresso = Color(0xFF2B1D14);
  static const ink = Color(0xFF3B2618);
  static const muted = Color(0xFF7A5C43);
  static const danger = Color(0xFFB4432F);
  static const warn = Color(0xFFC98A1B);
  static const good = Color(0xFF5E7D3A);
}

TextStyle display(double size, {Color color = AppColors.espresso, FontWeight weight = FontWeight.w600}) =>
    TextStyle(fontFamily: 'Fraunces', fontSize: size, fontWeight: weight, color: color, height: 1.1);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brown600,
      primary: AppColors.brown600,
      onPrimary: AppColors.butter50,
      secondary: AppColors.butter300,
      onSecondary: AppColors.espresso,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.cream,
  );
  final text = base.textTheme.apply(
    fontFamily: 'PlusJakartaSans',
    bodyColor: AppColors.ink,
    displayColor: AppColors.espresso,
  );
  final radius = BorderRadius.circular(14);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.espresso,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.espresso),
    ),
    cardTheme: CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.line)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.lineStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.lineStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.caramel, width: 2)),
      labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.muted),
      hintStyle: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.muted.withValues(alpha: 0.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brown600,
        foregroundColor: AppColors.butter50,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brown600,
        side: const BorderSide(color: AppColors.lineStrong),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.brown600, textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.butter300,
      labelTextStyle: WidgetStatePropertyAll(const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.paper,
      selectedColor: AppColors.brown600,
      side: const BorderSide(color: AppColors.lineStrong),
      labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.brown600, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.butter50, fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(backgroundColor: AppColors.espresso, contentTextStyle: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.butter50)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brown600,
      foregroundColor: AppColors.butter50,
    ),
  );
}
