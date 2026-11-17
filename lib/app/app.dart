import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/profile/state/user_profile_notifier.dart';

class LumivoApp extends ConsumerWidget {
  const LumivoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final theme = switch (profile.themeMode) {
      'oled' => AppTheme.oled,
      'dark' => AppTheme.dark,
      _ => AppTheme.light,
    };

    return MaterialApp(
      title: 'Lumivo',
      debugShowCheckedModeBanner: false,
      // Legacy routes still contain immutable dark tokens. Keep them readable
      // while the redesigned home opts into the user's semantic palette.
      theme: profile.themeMode == 'oled' ? AppTheme.oled : AppTheme.dark,
      locale: Locale(profile.language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || profile.reducedMotion,
          ),
          child: child!,
        );
      },
      home: Theme(data: theme, child: const DashboardScreen()),
    );
  }
}
