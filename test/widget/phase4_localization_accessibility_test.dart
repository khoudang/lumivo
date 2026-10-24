import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/app.dart';
import 'package:lumivo/app/providers.dart';

import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/energy/presentation/energy_screen.dart';
import 'package:lumivo/features/onboarding/presentation/add_device_sheet.dart';
import 'package:lumivo/features/rooms/presentation/rooms_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 4 Localization & Accessibility Test Suite', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
    });

    tearDown(() async {
      await repository.dispose();
    });

    void setupViewport(WidgetTester tester,
        {Size size = const Size(800, 1400)}) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    test('AppLocalizations unit tests for EN and VI mappings', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      final l10nVi = AppLocalizations(const Locale('vi'));

      expect(l10nEn.home, 'Home');
      expect(l10nVi.home, 'Trang chủ');

      expect(l10nEn.welcomeHome, 'Welcome home ✦');
      expect(l10nVi.welcomeHome, 'Chào mừng về nhà ✦');

      expect(l10nEn.deviceTypeName(DeviceType.light), 'Light');
      expect(l10nVi.deviceTypeName(DeviceType.light), 'Đèn chiếu sáng');

      expect(l10nEn.deviceTypeName(DeviceType.ac), 'Climate AC');
      expect(l10nVi.deviceTypeName(DeviceType.ac), 'Điều hòa');

      expect(l10nEn.devicesCount(1), '1 device');
      expect(l10nEn.devicesCount(3), '3 devices');
      expect(l10nVi.devicesCount(1), '1 thiết bị');
      expect(l10nVi.devicesCount(3), '3 thiết bị');
    });

    testWidgets(
        'Live UI locale switching updates Dashboard and Navigation to Vietnamese',
        (WidgetTester tester) async {
      setupViewport(tester);
      final container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LumivoApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Initial English Strings
      expect(find.text('Welcome home ✦'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('nav_tab_1')),
              matching: find.text('Rooms')),
          findsOneWidget);
      expect(find.text('Automation'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Quick Scenes'), findsOneWidget);

      // Switch Language to Vietnamese dynamically
      container.read(userProfileProvider.notifier).updateLanguage('vi');
      await tester.pumpAndSettle();

      // Verify Vietnamese Localized Strings
      expect(find.text('Chào mừng về nhà ✦'), findsOneWidget);
      expect(find.text('Trang chủ'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('nav_tab_1')),
              matching: find.text('Phòng')),
          findsOneWidget);
      expect(find.text('Tự động'), findsOneWidget);
      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.text('Yêu thích'), findsOneWidget);
      expect(find.text('Kịch bản nhanh'), findsOneWidget);

      // Switch back to English dynamically
      container.read(userProfileProvider.notifier).updateLanguage('en');
      await tester.pumpAndSettle();

      expect(find.text('Welcome home ✦'), findsOneWidget);
      expect(find.text('Trang chủ'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets(
        'Accessibility font scaling at 1.5x and 2.0x does not cause RenderFlex overflow',
        (WidgetTester tester) async {
      // Constrained mobile viewport
      setupViewport(tester, size: const Size(360, 640));

      final container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      Widget buildScaledWidget(Widget child, double scale) {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(body: child),
            ),
          ),
        );
      }

      // Test Dashboard at 1.5x scale
      await tester.pumpWidget(buildScaledWidget(const DashboardScreen(), 1.5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test Dashboard at 2.0x scale
      await tester.pumpWidget(buildScaledWidget(const DashboardScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test Rooms at 2.0x scale
      await tester.pumpWidget(buildScaledWidget(const RoomsScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test Energy at 2.0x scale
      await tester.pumpWidget(buildScaledWidget(const EnergyScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test Settings at 2.0x scale
      await tester.pumpWidget(buildScaledWidget(const SettingsScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Semantics annotations exist on Device Cards and interactive controls',
        (WidgetTester tester) async {
      setupViewport(tester);

      final container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LumivoApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Semantics for power toggle buttons
      final powerButton = find.byKey(const Key('device_power_btn_light-1'));
      expect(powerButton, findsOneWidget);

      final semantics = tester.getSemantics(powerButton);
      expect(semantics.label.isNotEmpty, isTrue);

      // Semantics on navigation tabs
      final homeTab = find.byKey(const Key('nav_tab_0'));
      expect(homeTab, findsOneWidget);
      final homeSemantics = tester.getSemantics(homeTab);
      expect(homeSemantics.label.isNotEmpty, isTrue);
    });

    testWidgets(
        'Reduced motion preference stops continuous looping animations in AddDeviceSheet',
        (WidgetTester tester) async {
      setupViewport(tester);

      final container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // Enable reduced motion
      container.read(userProfileProvider.notifier).setReducedMotion(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AddDeviceSheet(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // With reduced motion, pumpAndSettle finishes quickly without looping indefinitely
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(AddDeviceSheet), findsOneWidget);
    });
  });
}
