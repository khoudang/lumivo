import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/app/app.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/features/search/presentation/device_search_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/dashboard/widgets/device_card.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  testWidgets('home prioritizes room controls over decorative telemetry',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MockDeviceRepository(responseDelay: Duration.zero);
    addTearDown(repository.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [deviceRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();
    final brand = tester.getRect(find.text('LUMIVO'));
    expect(brand.left, greaterThanOrEqualTo(0));
    expect(brand.right, lessThanOrEqualTo(390));
    expect(find.text('26.5°C'), findsNothing);
    expect(find.text('65%'), findsNothing);
    expect(find.text('2.4 kWh'), findsNothing);
    expect(find.byKey(const Key('device_card_light-1')).hitTestable(),
        findsOneWidget);
    final card = tester.widget<AnimatedContainer>(find
        .descendant(
          of: find.byType(DeviceCard).first,
          matching: find.byType(AnimatedContainer),
        )
        .first);
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.boxShadow, isNull);
    final power = find.byKey(const Key('device_power_btn_light-1'));
    expect(power.hitTestable(), findsOneWidget);
    await tester.tap(power);
    await tester.pumpAndSettle();
    expect(
        repository.devices.firstWhere((d) => d.id == 'light-1').isOn, isFalse);
  });
  testWidgets('320-wide large text keeps every dashboard section usable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MockDeviceRepository(responseDelay: Duration.zero);
    addTearDown(repository.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [deviceRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
          builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        find.descendant(
            of: find.byType(DeviceCard), matching: find.byType(FittedBox)),
        findsNothing,
        reason:
            'Device labels must wrap rather than cancel accessibility text scaling');
    for (var i = 0; i < 9; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'light dashboard does not leak light theme into legacy tabs or routes',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MockDeviceRepository(responseDelay: Duration.zero);
    addTearDown(repository.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      deviceRepositoryProvider.overrideWithValue(repository),
      userProfileProvider.overrideWith((ref) => UserProfileNotifier(
          HomePersistenceManager.defaultUserProfile
              .copyWith(themeMode: 'light'))),
    ], child: const LumivoApp()));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(DeviceCard).first)).brightness,
        Brightness.light);
    await tester.tap(find.byKey(const Key('nav_tab_4')));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('nav_tab_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard_search_button')));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(DeviceSearchScreen))).brightness,
        Brightness.dark);
  });
  testWidgets(
      'explicit custom section order is not overridden by calm defaults',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MockDeviceRepository(responseDelay: Duration.zero);
    addTearDown(repository.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [deviceRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    final notifier = container.read(dashboardConfigProvider.notifier);
    notifier.setConfig(notifier.state.copyWith(sectionOrder: [
      DashboardSection.favorites,
      DashboardSection.devices,
    ]));
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.text('Favorites')).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const Key('device_card_light-1')))
            .dy));
  });

  for (final mode in ['dark', 'oled']) {
    testWidgets('saved $mode mode is respected by the home surface',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MockDeviceRepository(responseDelay: Duration.zero);
      addTearDown(repository.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        deviceRepositoryProvider.overrideWithValue(repository),
        userProfileProvider.overrideWith((ref) => UserProfileNotifier(
            HomePersistenceManager.defaultUserProfile
                .copyWith(themeMode: mode))),
      ], child: const LumivoApp()));
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(DeviceCard).first));
      expect(theme.brightness, Brightness.dark);
      if (mode == 'oled') expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(tester.takeException(), isNull);
    });
  }
}
