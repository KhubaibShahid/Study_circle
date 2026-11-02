import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF0B0D17);
  static const surface = Color(0xFF151827);
  static const surface2 = Color(0xFF1E2238);
  static const border = Color(0xFF2A2F48);
  static const primary = Color(0xFF7C5CFF);
  static const accent = Color(0xFF22D3EE);
  static const pink = Color(0xFFF472B6);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const text = Color(0xFFEDEEF6);
  static const muted = Color(0xFF8B90AB);

  static const gradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const warmGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color color = AppColors.text}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color, height: 1.15);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final text = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  final radius = BorderRadius.circular(14);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: text.copyWith(
      headlineMedium: display(26),
      titleLarge: display(20),
      titleMedium: display(16, weight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface2,
      contentTextStyle: GoogleFonts.inter(color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    dividerColor: AppColors.border,
    splashFactory: InkSparkle.splashFactory,
  );
}
