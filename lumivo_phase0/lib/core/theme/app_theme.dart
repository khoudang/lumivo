import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B0F17);
  static const surface = Color(0xFF171D29);
  static const surfaceElevated = Color(0xFF1D2635);
  static const primary = Color(0xFF8B7CFF);
  static const cyan = Color(0xFF43D9E8);
  static const green = Color(0xFF66DDB0);
  static const muted = Color(0xFF9CA9BD);
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.primary,
          thumbColor: AppColors.primary,
          inactiveTrackColor: AppColors.surfaceElevated,
        ),
      );
}
