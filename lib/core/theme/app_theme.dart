import 'package:flutter/material.dart';

/// Shared dark-mode tokens derived from the mobile design handoff.
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF131417);
  static const surfaceRaised = Color(0xFF1C1C1E);
  static const border = Color(0xFF2C2C2E);
  static const accent = Color(0xFF30D158);
  static const destructive = Color(0xFFFF453A);
}

class AppTheme {
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.destructive,
    ),
    // Intentionally use the platform system font. This matches the handoff and
    // avoids runtime font downloads from a private-network app.
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardThemeData(
      color: AppColors.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF6D6D72)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
    ),
  );
}
