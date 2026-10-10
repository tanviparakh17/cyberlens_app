import 'package:flutter/material.dart';

/// All colors of the app in one place. Change a value here to re-theme everything.
class AppColors {
  static const Color mint = Color(0xFF7ED9C0);
  static const Color mintDark = Color(0xFF2FA58A);
  static const Color mintSoft = Color(0xFFD5F3EA);
  static const Color sky = Color(0xFF8CCBF5);
  static const Color skyDark = Color(0xFF3B9AD9);
  static const Color skySoft = Color(0xFFDCEFFB);

  static const Color background = Color(0xFFF3FBF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFEAF7F4);

  static const Color ink = Color(0xFF23414B); // main text
  static const Color muted = Color(0xFF6B8791); // secondary text
  static const Color faint = Color(0xFF9DB4BC); // hints, small numbers
  static const Color track = Color(0xFFDDEFEC); // borders, progress bar background

  static const Color safe = Color(0xFF3DBE8B);
  static const Color warn = Color(0xFFF2A65A);
  static const Color danger = Color(0xFFE5677B);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.mint,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.mintDark,
    secondary: AppColors.skyDark,
    surface: AppColors.card,
    onSurface: AppColors.ink,
  );

  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

  OutlineInputBorder border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.faint),
      border: border(AppColors.track),
      enabledBorder: border(AppColors.track),
      focusedBorder: border(AppColors.mintDark, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: AppColors.ink,
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mintDark,
        side: const BorderSide(color: AppColors.mint, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.skyDark),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: AppColors.mint,
    ),
  );
}
