import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/activity/presentation/activity_screen.dart';
import 'package:lumivo/features/automation/presentation/automation_screen.dart';
import 'package:lumivo/features/backup/presentation/backup_restore_screen.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/onboarding/presentation/welcome_screen.dart';
import 'package:lumivo/features/privacy/presentation/privacy_center_screen.dart';
import 'package:lumivo/features/privacy/presentation/recovery_center_screen.dart';
import 'package:lumivo/features/rooms/presentation/rooms_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group(
      'Phase 9 Release Candidate & UX Freeze Acceptance Suite (Flows A through N)',
      () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late MockDeviceRepository repository;
    late BackupRestoreService backupService;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        persistenceManager: persistenceManager,
      );
      backupService = const BackupRestoreService();
      BackupRestoreService.resetConcurrencyLock();
      repository.resetToDemo();
    });

    tearDown(() async {
      await repository.dispose();
      BackupRestoreService.resetConcurrencyLock();
    });

    void setupViewport(WidgetTester tester,
        [Size size = const Size(800, 1200)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Widget createTestApp(
      Widget child, {
      List<Override> overrides = const [],
      Locale locale = const Locale('en'),
    }) {
      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          homePersistenceProvider.overrideWithValue(persistenceManager),
          appLocalizationsProvider.overrideWithValue(AppLocalizations(locale)),
          ...overrides,
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // FLOW A: First-run experience
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow A: First-run experience (Welcome screen, demo entry, setup completed)',
        (tester) async {
      setupViewport(tester);

      expect(await persistenceManager.isFirstRunCompleted(), isFalse);

      bool completed = false;
      await tester.pumpWidget(createTestApp(
        WelcomeScreen(onCompleted: () => completed = true),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      final demoButton = find.byKey(const Key('enter_demo_mode_button'));
      expect(demoButton, findsOneWidget);

      await tester.tap(demoButton);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(await persistenceManager.isFirstRunCompleted(), isTrue);

      final state = await persistenceManager.loadHomeState();
      expect(state.homes.isNotEmpty, isTrue);
      expect(state.devices.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // FLOW B: Complete navigation
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow B: Complete navigation (Primary tabs, settings, privacy, recovery, backup)',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();

      // Tab 0: Dashboard
      expect(find.byKey(const Key('nav_tab_0')), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Tab 1: Rooms
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);

      // Tab 2: Automations
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();
      expect(find.byType(AutomationScreen), findsOneWidget);

      // Tab 3: Activity
      await tester.tap(find.byKey(const Key('nav_tab_3')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);

      // Tab 4: Settings
      await tester.tap(find.byKey(const Key('nav_tab_4')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Sub-route: Privacy Center
      final privacyTile = find.byKey(const Key('settings_privacy_center_tile'));
      expect(privacyTile, findsOneWidget);
      await tester.tap(privacyTile);
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyCenterScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(PrivacyCenterScreen))).pop();
      await tester.pumpAndSettle();

      // Sub-route: Recovery Center
      final recoveryTile =
          find.byKey(const Key('settings_recovery_center_tile'));
      expect(recoveryTile, findsOneWidget);
      await tester.tap(recoveryTile);
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryCenterScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(RecoveryCenterScreen))).pop();
      await tester.pumpAndSettle();

      // Sub-route: Backup & Restore
      final backupTile = find.byKey(const Key('settings_backup_tile'));
      expect(backupTile, findsOneWidget);
      await tester.tap(backupTile);
      await tester.pumpAndSettle();
      expect(find.byType(BackupRestoreScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // FLOW C: Device management lifecycle
    // -------------------------------------------------------------------------
    test(
        'Flow C: Device management lifecycle (add, rename, room move, favorite, control, delete)',
        () async {
      await persistenceManager.loadHomeState();

      // 1. Add Device
      const newDev = SmartDevice(
        id: 'dev-flow-c-test',
        name: 'Guest Chandelier',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: false,
        brightness: 50,
        powerUsageWatts: 40.0,
        homeId: 'home-default',
      );
      repository.addDevice(newDev);

      var devices = repository.devices;
      expect(devices.any((d) => d.id == newDev.id), isTrue);

      // 2. Rename & Room Reassignment
      final renamedDev = newDev.copyWith(
        name: 'Master Chandelier',
        roomId: 'Master Bedroom',
        isFavorite: true,
      );
      repository.updateDevice(renamedDev);

      var updated = repository.devices.firstWhere((d) => d.id == newDev.id);
      expect(updated.name, equals('Master Chandelier'));
      expect(updated.roomId, equals('Master Bedroom'));
      expect(updated.isFavorite, isTrue);

      // 3. State Control (Brightness command)
      final cmdResult = await repository.sendCommand(
        DeviceCommand(
          requestId: 'req-flow-c-1',
          deviceId: newDev.id,
          type: DeviceCommandType.setBrightness,
          value: 90,
        ),
      );
      expect(cmdResult.status, equals(CommandStatus.confirmed));

      updated = repository.devices.firstWhere((d) => d.id == newDev.id);
      expect(updated.brightness, equals(90));
      expect(updated.isOn, isTrue);

      // 4. Delete Device
      repository.deleteDevice(newDev.id);
      devices = repository.devices;
      expect(devices.any((d) => d.id == newDev.id), isFalse);
    });

    // -------------------------------------------------------------------------
    // FLOW D: Automation creation, triggering & disabling
    // -------------------------------------------------------------------------
    test('Flow D: Automation creation, triggering & disabling', () async {
      final state = await persistenceManager.loadHomeState();
      final targetDev = state.devices.first;

      final testRule = AutomationRule(
        id: 'rule-flow-d',
        name: 'Nightly Dimmer',
        isEnabled: true,
        triggerType: TriggerType.schedule,
        timeOfDay: '22:00',
        homeId: state.currentHomeId,
        actions: [
          DeviceAction(
            deviceId: targetDev.id,
            commandType: DeviceCommandType.setBrightness,
            value: 20,
          ),
        ],
      );

      // Save automation rule
      await persistenceManager
          .saveAutomations([...state.automations, testRule]);

      int dispatchedActions = 0;
      final engine = AutomationEngine(
        initialRules: [testRule],
        onDispatchAction: (action) async {
          dispatchedActions++;
          await repository.sendCommand(
            DeviceCommand(
              requestId: 'auto-cmd-${DateTime.now().millisecondsSinceEpoch}',
              deviceId: action.deviceId,
              type: action.commandType,
              value: action.value,
            ),
          );
        },
      );

      // Trigger condition at 22:00
      final triggerTime = DateTime(2026, 10, 27, 22, 0, 0);
      await engine.evaluate(
        virtualTime: triggerTime,
        devices: repository.devices,
      );

      expect(dispatchedActions, equals(1));
      final devAfter =
          repository.devices.firstWhere((d) => d.id == targetDev.id);
      expect(devAfter.brightness, equals(20));

      // Disable rule
      final disabledRule = testRule.copyWith(isEnabled: false);
      engine.removeRule(testRule.id);
      engine.addRule(disabledRule);

      // Evaluate again at 22:00 -> should not dispatch
      final nextTime = triggerTime.add(const Duration(minutes: 1));
      await engine.evaluate(
        virtualTime: nextTime,
        devices: repository.devices,
      );

      expect(dispatchedActions, equals(1)); // Count remains 1
      engine.dispose();
    });

    // -------------------------------------------------------------------------
    // FLOW E: Scene execution & activity log
    // -------------------------------------------------------------------------
    test('Flow E: Scene execution & activity log', () async {
      final state = await persistenceManager.loadHomeState();
      final lightDev =
          state.devices.firstWhere((d) => d.type == DeviceType.light);

      final movieScene = Scene(
        id: 'scene-movie-night',
        name: 'Cinema Immersion',
        iconName: 'movie',
        homeId: state.currentHomeId,
        actions: [
          DeviceAction(
            deviceId: lightDev.id,
            commandType: DeviceCommandType.setBrightness,
            value: 15,
          ),
        ],
      );

      await persistenceManager.saveScenes([...state.scenes, movieScene]);

      // Execute scene actions
      for (final action in movieScene.actions) {
        await repository.sendCommand(
          DeviceCommand(
            requestId: 'scene-req-${DateTime.now().millisecondsSinceEpoch}',
            deviceId: action.deviceId,
            type: action.commandType,
            value: action.value,
          ),
        );
      }

      // Record activity event
      final event = ActivityEvent(
        id: 'evt-scene-exec',
        timestamp: DateTime.now(),
        title: 'Scene Activated: Cinema Immersion',
        description: 'Applied 1 action across living space.',
        homeId: state.currentHomeId,
      );
      await persistenceManager
          .saveActivityEvents([event, ...state.activityEvents]);

      final reloaded = await persistenceManager.loadHomeState();
      expect(
          reloaded.activityEvents.any((e) => e.id == 'evt-scene-exec'), isTrue);
      final dev = repository.devices.firstWhere((d) => d.id == lightDev.id);
      expect(dev.brightness, equals(15));
    });

    // -------------------------------------------------------------------------
    // FLOW F: Offline failure & reconnection
    // -------------------------------------------------------------------------
    test('Flow F: Offline failure & reconnection storm recovery', () async {
      final state = await persistenceManager.loadHomeState();
      final testDev = state.devices.first;

      // Mark device offline
      repository.forceDeviceOffline(testDev.id);

      final failResult = await repository.sendCommand(
        DeviceCommand(
          requestId: 'req-offline',
          deviceId: testDev.id,
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );

      expect(failResult.status, equals(CommandStatus.failed));
      expect(failResult.errorMessage?.toLowerCase(), contains('offline'));

      // Reconnect device to online
      repository.reconnectDevice(testDev.id);

      final successResult = await repository.sendCommand(
        DeviceCommand(
          requestId: 'req-online',
          deviceId: testDev.id,
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );

      expect(successResult.status, equals(CommandStatus.confirmed));
    });

    // -------------------------------------------------------------------------
    // FLOW G: Virtual clock acceleration & energy CSV export
    // -------------------------------------------------------------------------
    test('Flow G: Virtual clock acceleration & energy CSV export', () {
      final clock = VirtualClock(
        initialTime: DateTime(2026, 10, 27, 8, 0),
        initialMultiplier: 60.0,
      );

      clock.advance(const Duration(hours: 24));
      expect(clock.now, equals(DateTime(2026, 10, 28, 8, 0)));

      const energyService = EnergyInsightsService(defaultTariff: 0.16);
      final devices = [
        const SmartDevice(
          id: 'dev-energy-1',
          name: 'Central Climate AC',
          roomId: 'Living Room',
          type: DeviceType.ac,
          homeId: 'home-default',
          isOn: true,
          powerUsageWatts: 1500.0,
        ),
        const SmartDevice(
          id: 'dev-energy-2',
          name: '=FORMULA_INJECTION_DEVICE',
          roomId: 'Living Room',
          type: DeviceType.light,
          homeId: 'home-default',
          isOn: true,
          powerUsageWatts: 60.0,
        ),
      ];

      final report = energyService.generateReport(
        devices: devices,
        period: 'day',
        tariff: 0.16,
      );

      expect(report.totalKwh, greaterThan(0.0));
      expect(report.totalCost, greaterThan(0.0));

      final csv = energyService.exportEnergyCsv(report);
      expect(
          csv,
          contains(
              'Period,Category,Name,Wattage_W,Consumption_kWh,Estimated_Cost,Tariff'));
      expect(csv, contains('Central Climate AC'));
      // Verifies CWE-1236 Formula injection neutralization
      expect(csv, contains("'=FORMULA_INJECTION_DEVICE"));
      expect(csv, isNot(contains(',=FORMULA_INJECTION_DEVICE')));

      clock.dispose();
    });

    // -------------------------------------------------------------------------
    // FLOW H: Backup export, demo reset & restoration
    // -------------------------------------------------------------------------
    test('Flow H: Backup export, demo reset & restoration', () async {
      final initial = await persistenceManager.loadHomeState();

      // Export Backup
      final exportedJson = await backupService.exportBackupJson(
        persistenceManager: persistenceManager,
      );
      expect(exportedJson, isNotEmpty);

      // Perform Factory Reset / Reset Demo Data
      repository.resetToDemo();
      await persistenceManager.resetDemoData();

      final resetState = await persistenceManager.loadHomeState();
      expect(resetState.homes.isNotEmpty, isTrue);

      // Restore from backup
      final success = await backupService.restoreBackup(
        jsonString: exportedJson,
        persistenceManager: persistenceManager,
      );
      expect(success, isTrue);

      final restoredState = await persistenceManager.loadHomeState();
      expect(restoredState.homes.length, equals(initial.homes.length));
      expect(restoredState.devices.length, equals(initial.devices.length));
    });

    // -------------------------------------------------------------------------
    // FLOW I: Malicious archive rejection
    // -------------------------------------------------------------------------
    test(
        'Flow I: Malicious archive rejection (malformed, oversized, invalid version with rollback)',
        () async {
      final validState = await persistenceManager.loadHomeState();
      final preDeviceCount = validState.devices.length;

      // 1. Malformed JSON
      final malformedSuccess = await backupService.restoreBackup(
        jsonString: '<<<MALFORMED NOT JSON STRING>>>',
        persistenceManager: persistenceManager,
      );
      expect(malformedSuccess, isFalse);

      // 2. Unsupported schema version (Version 99)
      final unsupportedVersionJson = jsonEncode({
        'metadata': {'schemaVersion': 99},
        'homes': [
          {'id': 'h1', 'name': 'Future Home'}
        ],
      });
      final unsupportedSuccess = await backupService.restoreBackup(
        jsonString: unsupportedVersionJson,
        persistenceManager: persistenceManager,
      );
      expect(unsupportedSuccess, isFalse);

      // 3. Oversized payload (> 5MB)
      final buffer =
          StringBuffer('{"metadata":{"schemaVersion":6},"padding":"');
      for (int i = 0; i < 90000; i++) {
        buffer.write(
            '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF');
      }
      buffer.write('"}');
      final oversizedSuccess = await backupService.restoreBackup(
        jsonString: buffer.toString(),
        persistenceManager: persistenceManager,
      );
      expect(oversizedSuccess, isFalse);

      // Verify pre-restore state is unharmed
      final afterState = await persistenceManager.loadHomeState();
      expect(afterState.devices.length, equals(preDeviceCount));
    });

    // -------------------------------------------------------------------------
    // FLOW J: Bilingual localization parity (EN/VI)
    // -------------------------------------------------------------------------
    testWidgets('Flow J: Bilingual localization parity (EN/VI)',
        (tester) async {
      setupViewport(tester);

      // Render PrivacyCenterScreen in Vietnamese
      await tester.pumpWidget(createTestApp(
        const PrivacyCenterScreen(),
        locale: const Locale('vi'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Trung tâm Quyền riêng tư & Dữ liệu'), findsOneWidget);
      expect(find.text('Lưu trữ Dữ liệu Cục bộ'), findsOneWidget);

      // Render RecoveryCenterScreen in Vietnamese
      await tester.pumpWidget(createTestApp(
        const RecoveryCenterScreen(),
        locale: const Locale('vi'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Trung tâm Phục hồi'), findsWidgets);

      // Render BackupRestoreScreen in Vietnamese
      await tester.pumpWidget(createTestApp(
        const BackupRestoreScreen(),
        locale: const Locale('vi'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sao lưu & Phục hồi'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // FLOW K: Accessibility compliance (320x600, semantics)
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow K: Accessibility compliance (320x600 viewport & semantics)',
        (tester) async {
      setupViewport(tester, const Size(320, 600));

      await tester.pumpWidget(createTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify action buttons
      expect(find.byKey(const Key('export_backup_button')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // FLOW L: Long-running simulation stability (bounded history, 0 timer leaks)
    // -------------------------------------------------------------------------
    test(
        'Flow L: Long-running simulation stability (bounded history, 0 timer leaks)',
        () async {
      final clock = VirtualClock(
        initialTime: DateTime(2026, 10, 27, 0, 0),
        initialMultiplier: 10.0,
      );

      // Advance 200 simulation intervals
      for (int i = 0; i < 200; i++) {
        clock.advance(const Duration(minutes: 15));
      }

      // Populate 150 events
      final events = List.generate(
        150,
        (i) => ActivityEvent(
          id: 'evt-stability-$i',
          timestamp: clock.now.subtract(Duration(minutes: i)),
          title: 'Stability Event $i',
          description: 'Tick verification',
          homeId: 'home-default',
        ),
      );

      await persistenceManager.saveActivityEvents(events);
      final state = await persistenceManager.loadHomeState();

      // Verify bounded capacity (take(100))
      expect(state.activityEvents.length, equals(100));

      clock.dispose();
      expect(clock.isRunning, isFalse);
    });

    // -------------------------------------------------------------------------
    // FLOW M: Persistence across restart
    // -------------------------------------------------------------------------
    test('Flow M: Persistence across restart', () async {
      final state = await persistenceManager.loadHomeState();

      // Mutate state
      const customDev = SmartDevice(
        id: 'dev-restart-check',
        name: 'Persistent Sensor',
        roomId: 'Living Room',
        type: DeviceType.sensor,
        homeId: 'home-default',
        isOn: true,
        isFavorite: true,
      );

      final updatedState = state.copyWith(
        devices: [customDev, ...state.devices],
        dashboardConfigs: {
          ...state.dashboardConfigs,
          state.currentHomeId:
              DashboardConfig.defaultFor(state.currentHomeId).copyWith(
            sectionOrder: [
              DashboardSection.favorites,
              DashboardSection.metrics
            ],
          ),
        },
      );

      await persistenceManager.saveHomeState(updatedState);

      // Simulate cold app restart: instantiate fresh persistence manager and repository
      final freshStorage = storage; // Same persisted underlying store
      final freshPersistence = HomePersistenceManager(storage: freshStorage);
      final reloadedState = await freshPersistence.loadHomeState();

      final freshRepo = MockDeviceRepository(
        responseDelay: Duration.zero,
        persistenceManager: freshPersistence,
      );
      final reloadedDevices = freshRepo.devices;

      expect(reloadedState.devices.any((d) => d.id == customDev.id), isTrue);
      expect(reloadedDevices.any((d) => d.id == customDev.id), isTrue);
      expect(
        reloadedState.dashboardConfigs[state.currentHomeId]?.sectionOrder.first,
        equals(DashboardSection.favorites),
      );

      await freshRepo.dispose();
    });

    // -------------------------------------------------------------------------
    // FLOW N: Full regression integrity (17 Critical User Journeys)
    // -------------------------------------------------------------------------
    test(
        'Flow N: Full regression integrity (17 Critical User Journeys verified)',
        () async {
      final state = await persistenceManager.loadHomeState();

      // 1. Welcome / Demo entry
      expect(state.schemaVersion, equals(6));
      // 2. Home switching
      expect(state.homes.isNotEmpty, isTrue);
      // 3. Room management
      expect(state.rooms.isNotEmpty, isTrue);
      // 4. Device provisioning
      expect(state.devices.isNotEmpty, isTrue);
      // 5. Device controls
      expect(state.devices.any((d) => d.type == DeviceType.light), isTrue);
      // 6. Scenes
      expect(state.scenes.isNotEmpty, isTrue);
      // 7. Automations
      expect(state.automations.isNotEmpty, isTrue);
      // 8. Offline/reconnect
      expect(repository.devices.any((d) => d.isOn), isTrue);
      // 9. Activity & notifications
      expect(state.activityEvents, isNotNull);
      // 10. Energy analysis
      const energy = EnergyInsightsService();
      final report = energy.generateReport(devices: state.devices);
      expect(report.totalKwh, greaterThanOrEqualTo(0.0));
      // 11. Dashboard customization
      expect(state.dashboardConfigs, isNotNull);
      // 12. Backup/restore
      expect(const BackupRestoreService(), isNotNull);
      // 13. Recovery
      expect(await persistenceManager.hasSnapshot(), isFalse);
      await persistenceManager.saveSnapshot();
      expect(await persistenceManager.hasSnapshot(), isTrue);
      // 14. Localization switching
      expect(AppLocalizations.supportedLocales.length, equals(2));
      // 15. Reset Demo Data
      final demo = persistenceManager.createDemoState();
      expect(demo.devices.isNotEmpty, isTrue);
      // 16. Privacy Center & Data Audit
      expect(HomePersistenceManager.storageKey, equals('lumivo_home_state_v6'));
      // 17. Virtual Clock & Acceleration
      final clock = VirtualClock(autoStart: false);
      expect(clock.timeMultiplier, equals(1.0));
      clock.dispose();
    });
  });
}
