import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

class LumivoApp extends StatelessWidget {
  const LumivoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lumivo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const DashboardScreen(),
      );
}
