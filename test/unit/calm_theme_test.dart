import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/theme/app_theme.dart';

void main() {
  test('dark theme uses restrained forest accents and neutral surfaces', () {
    final theme = AppTheme.dark;
    expect(theme.colorScheme.primary, const Color(0xFF9FCAAF));
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(.7));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF141815));
  });
  test('light theme has warm neutral surfaces and accessible text contrast',
      () {
    final theme = AppTheme.light;
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F3ED));
    final colors = theme.colorScheme;
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + .05) / (values.first + .05);
    }

    expect(
        contrast(colors.onSurface, colors.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(colors.onSurfaceVariant, colors.surface),
        greaterThanOrEqualTo(4.5));
    expect(
        contrast(colors.onPrimary, colors.primary), greaterThanOrEqualTo(4.5));
    expect(contrast(colors.onPrimaryContainer, colors.primaryContainer),
        greaterThanOrEqualTo(4.5));
  });
  test('OLED uses true black without changing dark text semantics', () {
    expect(AppTheme.oled.scaffoldBackgroundColor, Colors.black);
    expect(AppTheme.oled.brightness, Brightness.dark);
    expect(AppTheme.oled.colorScheme.onSurface,
        AppTheme.dark.colorScheme.onSurface);
  });
}
