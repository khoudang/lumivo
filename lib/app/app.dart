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
    final theme = profile.themeMode == 'oled'
        ? AppTheme.dark.copyWith(
            scaffoldBackgroundColor: Colors.black,
            colorScheme: AppTheme.dark.colorScheme.copyWith(
              surface: const Color(0xFF080808),
            ),
          )
        : AppTheme.dark;

    return MaterialApp(
      title: 'Lumivo',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: Locale(profile.language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const DashboardScreen(),
    );
  }
}
