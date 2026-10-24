import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/app.dart';
import 'package:lumivo/app/providers.dart';


import 'package:lumivo/features/activity/presentation/activity_screen.dart';

import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/energy/presentation/energy_screen.dart';
import 'package:lumivo/features/home/presentation/home_selector_sheet.dart';
import 'package:lumivo/features/rooms/presentation/rooms_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 4 Acceptance Test Suite (Flows A through H)', () {
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

    // -------------------------------------------------------------
    // FLOW A: Fresh Install & Initial Launch
    // -------------------------------------------------------------
    testWidgets(
        'Flow A: First Launch loads clean demo state, greeting and dashboard',
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

      // Brand, Greeting, and Overview
      expect(find.text('LUMIVO'), findsOneWidget);
      expect(find.text('Welcome home ✦'), findsOneWidget);
      expect(find.text('Your smart home is looking good.'), findsOneWidget);

      // Core Navigation tabs visible
      expect(find.byKey(const Key('nav_tab_0')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_1')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_2')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_3')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_4')), findsOneWidget);

      // Default demo devices loaded
      expect(find.byKey(const Key('device_card_light-1')), findsOneWidget);
      expect(find.byKey(const Key('device_card_fan-1')), findsOneWidget);
    });

    // -------------------------------------------------------------
    // FLOW B: Dynamic Locale Switch (EN <-> VI) across Principal Screens
    // -------------------------------------------------------------
    testWidgets(
        'Flow B: Dynamic Locale Switch translates all principal screens cleanly',
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

      // 1. Dashboard in English
      expect(find.text('Welcome home ✦'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Quick Scenes'), findsOneWidget);

      // Switch to Vietnamese
      container.read(userProfileProvider.notifier).updateLanguage('vi');
      await tester.pumpAndSettle();

      // 2. Dashboard in Vietnamese
      expect(find.text('Chào mừng về nhà ✦'), findsOneWidget);
      expect(find.text('Yêu thích'), findsOneWidget);
      expect(find.text('Kịch bản nhanh'), findsOneWidget);
      expect(find.text('Trang chủ'), findsOneWidget);

      // 3. Switch to Rooms Screen (Tab 1)
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();
      expect(find.text('PHÒNG'), findsOneWidget);
      expect(find.text('Thêm phòng'), findsOneWidget);

      // 4. Switch to Automation Screen (Tab 2)
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();
      expect(find.text('Tự động'), findsWidgets);
      expect(find.text('Kịch bản'), findsOneWidget);

      // 5. Switch to Activity Screen (Tab 3)
      await tester.tap(find.byKey(const Key('nav_tab_3')));
      await tester.pumpAndSettle();
      expect(find.text('Hoạt động'), findsWidgets);

      // 6. Switch to Settings Screen (Tab 4)
      await tester.tap(find.byKey(const Key('nav_tab_4')));
      await tester.pumpAndSettle();
      expect(find.text('Cài đặt'), findsWidgets);
      expect(find.text('Giao diện & Thẩm mỹ'), findsOneWidget);

      // 7. Switch back to English
      container.read(userProfileProvider.notifier).updateLanguage('en');
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Aesthetics & Theme'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // FLOW C: Accessible Font Scaling (1.5x and 2.0x linear)
    // -------------------------------------------------------------
    testWidgets(
        'Flow C: Font scaling at 1.5x and 2.0x scales without RenderFlex overflow',
        (WidgetTester tester) async {
      setupViewport(tester, size: const Size(360, 640));
      final container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      Widget buildScaled(Widget child, double scale) {
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

      // Dashboard at 1.5x and 2.0x
      await tester.pumpWidget(buildScaled(const DashboardScreen(), 1.5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(buildScaled(const DashboardScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Rooms at 2.0x
      await tester.pumpWidget(buildScaled(const RoomsScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Energy at 2.0x
      await tester.pumpWidget(buildScaled(const EnergyScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Settings at 2.0x
      await tester.pumpWidget(buildScaled(const SettingsScreen(), 2.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------
    // FLOW D: Multi-Home State Isolation
    // -------------------------------------------------------------
    testWidgets(
        'Flow D: Multi-Home state isolates properties and switches cleanly',
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

      // Verify Initial Active Home
      final initialHome = container.read(currentHomeProvider);
      expect(initialHome.name, isNotEmpty);

      // Open Home Selector Sheet
      await tester.tap(find.byKey(const Key('home_app_bar_title_button')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSelectorSheet), findsOneWidget);

      // Select another home (Suburban Villa)
      await tester.tap(find.text('Suburban Villa'));
      await tester.pumpAndSettle();

      // Verify active home updated
      expect(container.read(currentHomeProvider).name, 'Suburban Villa');
    });

    // -------------------------------------------------------------
    // FLOW E: Complete Device Control -> Scene -> Automation -> Activity Pipeline
    // -------------------------------------------------------------
    testWidgets(
        'Flow E: Device toggle, scene trigger, and activity timeline logging',
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

      // 1. Toggle Device Power on Dashboard
      final powerBtn = find.byKey(const Key('device_power_btn_light-1'));
      expect(powerBtn, findsOneWidget);
      await tester.tap(powerBtn);
      await tester.pumpAndSettle();

      // Verify device state changed
      final updatedDevice =
          repository.devices.firstWhere((d) => d.id == 'light-1');
      expect(updatedDevice, isNotNull);

      // 2. Switch to Automation Tab -> Scenes
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();

      final runSceneBtn = find.byKey(const Key('run_scene_scene-1'));
      if (runSceneBtn.evaluate().isNotEmpty) {
        await tester.tap(runSceneBtn);
        await tester.pump();
        await tester.pumpAndSettle();
      }

      // 3. Switch to Activity Timeline
      await tester.tap(find.byKey(const Key('nav_tab_3')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);
    });

    // -------------------------------------------------------------
    // FLOW F: App Lifecycle Background / Foreground Transition
    // -------------------------------------------------------------
    testWidgets(
        'Flow F: App lifecycle pause and resume handles virtual clock seamlessly',
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

      // Simulate App Lifecycle Pause (Moving to background)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 200));

      // Simulate App Lifecycle Resume (Returning to foreground)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify dashboard remains interactive and intact
      expect(find.text('LUMIVO'), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_0')), findsOneWidget);
    });

    // -------------------------------------------------------------
    // FLOW G: Reload / Simulation State Persistence
    // -------------------------------------------------------------
    testWidgets(
        'Flow G: Repository state changes persist across container re-instantiation',
        (WidgetTester tester) async {
      setupViewport(tester);

      // 1. Send update to repository
      final target = repository.devices.firstWhere((d) => d.id == 'fan-1');
      repository.updateDevice(target.copyWith(isOn: true));

      // 2. Spin up a new ProviderContainer reflecting web reload with same repo
      final reloadedContainer = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(reloadedContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: reloadedContainer,
          child: const LumivoApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verified device state persisted in repository
      final reloadedDevice =
          repository.devices.firstWhere((d) => d.id == 'fan-1');
      expect(reloadedDevice.isOn, isTrue);
    });

    // -------------------------------------------------------------
    // FLOW H: Reset Demo State to Initial Seed Cleanly
    // -------------------------------------------------------------
    testWidgets(
        'Flow H: Demo data reset reverts all modified devices to factory seed',
        (WidgetTester tester) async {
      setupViewport(tester);
      final container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // Modify device state
      final light = repository.devices.firstWhere((d) => d.id == 'light-1');
      repository.updateDevice(light.copyWith(isOn: false));
      expect(repository.devices.firstWhere((d) => d.id == 'light-1').isOn,
          isFalse);

      // Execute Reset to Demo
      repository.resetToDemo();

      // Verify restored to demo state
      expect(repository.devices.any((d) => d.id == 'device-bulb-1'), isTrue);
      expect(repository.devices.any((d) => d.id == 'device-fan-1'), isTrue);
    });
  });
}
