import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App palette. Switches between dark and light; the whole app is rebuilt
/// when the theme changes, so widgets can read these directly.
class AppColors {
  static bool dark = true;

  static Color _p(int darkHex, int lightHex) => Color(dark ? darkHex : lightHex);

  static Color get bg => _p(0xFF0B0D17, 0xFFF5F6FB);
  static Color get surface => _p(0xFF151827, 0xFFFFFFFF);
  static Color get surface2 => _p(0xFF1E2238, 0xFFEEF0F7);
  static Color get border => _p(0xFF2A2F48, 0xFFE1E4EF);
  static Color get text => _p(0xFFEDEEF6, 0xFF14162B);
  static Color get muted => _p(0xFF8B90AB, 0xFF6B7090);

  static Color get primary => _p(0xFF7C5CFF, 0xFF6A48F5);
  static Color get accent => _p(0xFF22D3EE, 0xFF0AA5C2);
  static Color get pink => _p(0xFFF472B6, 0xFFDB4C97);
  static Color get success => _p(0xFF34D399, 0xFF14A874);
  static Color get warning => _p(0xFFFBBF24, 0xFFD18E00);
  static Color get danger => _p(0xFFF87171, 0xFFDC4747);

  // Gradients keep the bright brand colors in both themes (white text on top).
  static const LinearGradient gradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color ?? AppColors.text, height: 1.15);

ThemeData buildTheme(bool dark) {
  AppColors.dark = dark;
  final base = ThemeData(brightness: dark ? Brightness.dark : Brightness.light, useMaterial3: true);
  final text = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  final radius = BorderRadius.circular(14);
  final scheme = dark
      ? ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          error: AppColors.danger,
        )
      : ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          error: AppColors.danger,
        );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    textTheme: text.copyWith(
      headlineMedium: display(26),
      titleLarge: display(20),
      titleMedium: display(16, weight: FontWeight.w600),
    ),
    iconTheme: IconThemeData(color: AppColors.text),
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
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: AppColors.muted),
      labelStyle: TextStyle(color: AppColors.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? AppColors.surface2 : const Color(0xFF1E2238),
      contentTextStyle: GoogleFonts.inter(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface2,
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      side: BorderSide(color: AppColors.border),
      labelStyle: TextStyle(color: AppColors.text),
    ),
    popupMenuTheme: PopupMenuThemeData(color: AppColors.surface),
    dividerColor: AppColors.border,
    splashFactory: InkSparkle.splashFactory,
  );
}
