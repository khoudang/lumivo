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

/// Spacing tokens for consistent padding and margins across Lumivo
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

/// Corner radius tokens for uniform container geometry
abstract final class AppRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double card = 22.0;
  static const double dialog = 24.0;
  static const double sheet = 28.0;
}

/// Touch target accessibility minimums (WCAG 2.1 AA >= 48x48pt)
abstract final class AppTouchTargets {
  static const double min = 48.0;
}

/// Semantic themes are context-local; legacy AppColors remain immutable.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get oled => _build(Brightness.dark, oled: true);

  static ThemeData _build(Brightness brightness, {bool oled = false}) {
    final dark = brightness == Brightness.dark;
    final background = oled
        ? Colors.black
        : (dark ? const Color(0xFF141815) : const Color(0xFFF5F3ED));
    final surface = oled
        ? const Color(0xFF090C0A)
        : (dark ? const Color(0xFF1D231F) : const Color(0xFFFFFEFA));
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF315D47),
      brightness: brightness,
    ).copyWith(
      primary: dark ? const Color(0xFF9FCAAF) : const Color(0xFF315D47),
      onPrimary: dark ? const Color(0xFF143323) : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF293D30) : const Color(0xFFE3EBDD),
      onPrimaryContainer:
          dark ? const Color(0xFFDCEADB) : const Color(0xFF243C2D),
      surface: surface,
      onSurface: dark ? const Color(0xFFF0F1EA) : const Color(0xFF252B26),
      onSurfaceVariant:
          dark ? const Color(0xFFB6BDB4) : const Color(0xFF60685F),
      surfaceContainerHighest:
          dark ? const Color(0xFF2A312B) : const Color(0xFFECEDE5),
      outlineVariant: dark ? const Color(0xFF3D483F) : const Color(0xFFD8DDD2),
    );
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
          backgroundColor: background,
          foregroundColor: colors.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false),
      cardTheme: CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape:
              shape.copyWith(side: BorderSide(color: colors.outlineVariant))),
      dividerColor: colors.outlineVariant,
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              minimumSize: const Size(48, 48),
              shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.outlineVariant),
              minimumSize: const Size(48, 48),
              shape: shape)),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: shape),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.outlineVariant))),
      sliderTheme: SliderThemeData(
          activeTrackColor: colors.primary,
          thumbColor: colors.primary,
          inactiveTrackColor: colors.outlineVariant,
          trackHeight: 5,
          thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 0)),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: shape),
      chipTheme: ChipThemeData(
          backgroundColor: surface,
          selectedColor: colors.primaryContainer,
          side: BorderSide(color: colors.outlineVariant)),
    );
  }
}
