import 'package:flutter/material.dart';

abstract final class AppColors {
  // Deep space background
  static const background = Color(0xFF0B0F17);

  // Elevated surfaces
  static const surface = Color(0xFF171D29);
  static const surfaceElevated = Color(0xFF1D2635);
  static const surfaceBorder = Color(0xFF253043);
  static const surfaceBorderSubtle = Color(0x1FFFFFFF);

  // Accent and primary hues
  static const primary = Color(0xFF8B7CFF);
  static const primaryVariant = Color(0xFF6C5CE7);
  static const primaryGlow = Color(0x598B7CFF);

  static const cyan = Color(0xFF43D9E8);
  static const cyanGlow = Color(0x5943D9E8);

  static const green = Color(0xFF66DDB0);
  static const greenGlow = Color(0x5966DDB0);

  // Semantic & status colors
  static const warning = Color(0xFFFFBE7C);
  static const danger = Color(0xFFFF6B6B);
  static const blue = Color(0xFF77CFFF);
  static const muted = Color(0xFF9CA9BD);
  static const mutedDark = Color(0xFF66768F);

  // Text
  static const textPrimary = Color(0xFFF3F6FB);
  static const textSecondary = Color(0xFF9CA9BD);
  static const textDisabled = Color(0xFF5A6679);

  // Active state dark surface tints
  static const activeCardSurface = Color(0xFF2A244E);
  static const activeCardBorder = Color(0x808B7CFF);
  static const activeSecuritySurface = Color(0xFF17362E);
}

abstract final class AppGradients {
  static const primary = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryVariant],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryHorizontal = LinearGradient(
    colors: [AppColors.primary, Color(0xFFA294FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const accent = LinearGradient(
    colors: [AppColors.primary, AppColors.cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const surface = LinearGradient(
    colors: [AppColors.surfaceElevated, AppColors.surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const activeCard = LinearGradient(
    colors: [AppColors.activeCardSurface, Color(0xFF1A2131)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const activeSecurity = LinearGradient(
    colors: [AppColors.activeSecuritySurface, Color(0xFF152228)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppShadows {
  static const cardGlow = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const primaryGlow = [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const activeCardGlow = [
    BoxShadow(
      color: Color(0x358B7CFF),
      blurRadius: 24,
      spreadRadius: -2,
      offset: Offset(0, 8),
    ),
  ];

  static const greenGlow = [
    BoxShadow(
      color: AppColors.greenGlow,
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.cyan,
          onSecondary: Colors.black,
          tertiary: AppColors.green,
          onTertiary: Colors.black,
          error: AppColors.danger,
          onError: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(
              color: AppColors.surfaceBorder,
              width: 1,
            ),
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.primary,
          thumbColor: AppColors.primary,
          inactiveTrackColor: AppColors.surfaceElevated,
          overlayColor: Color(0x298B7CFF),
          trackHeight: 6,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceElevated,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          hintStyle: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
          ),
          prefixIconColor: AppColors.muted,
          suffixIconColor: AppColors.muted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.surfaceBorder),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          modalBarrierColor: Color(0xBF000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: const Color(0x3D8B7CFF),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
}
