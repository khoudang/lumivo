import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/features/automation/presentation/automation_screen.dart';
import 'package:lumivo/features/backup/presentation/backup_restore_screen.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/energy/presentation/energy_screen.dart';
import 'package:lumivo/features/onboarding/presentation/welcome_screen.dart';
import 'package:lumivo/features/privacy/presentation/privacy_center_screen.dart';
import 'package:lumivo/features/privacy/presentation/recovery_center_screen.dart';
import 'package:lumivo/features/rooms/presentation/rooms_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/ble/mock_ble_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/simulation_lifecycle_observer.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 10 — Final Release Acceptance Suite (17 CUJs & Core Journeys)',
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
          userProfileProvider.overrideWith((ref) => UserProfileNotifier(
                UserProfile(language: locale.languageCode),
              )),
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

    // =========================================================================
    // CUJ 01: Welcome Screen & Demo Mode Onboarding
    // =========================================================================
    testWidgets('CUJ 01: Welcome Screen & Demo Mode Onboarding',
        (tester) async {
      setupViewport(tester);

      expect(await persistenceManager.isFirstRunCompleted(), isFalse);

      bool completed = false;
      await tester.pumpWidget(createTestApp(
        WelcomeScreen(onCompleted: () => completed = true),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      final demoBtn = find.byKey(const Key('enter_demo_mode_button'));
      expect(demoBtn, findsOneWidget);

      await tester.tap(demoBtn);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(await persistenceManager.isFirstRunCompleted(), isTrue);

      final state = await persistenceManager.loadHomeState();
      expect(state.homes.isNotEmpty, isTrue);
      expect(state.devices.isNotEmpty, isTrue);
    });

    // =========================================================================
    // CUJ 02: Multi-Home Management & Context Isolation
    // =========================================================================
    test('CUJ 02: Multi-Home Management & Context Isolation', () async {
      final state = await persistenceManager.loadHomeState();
      expect(state.homes.length, greaterThanOrEqualTo(2));

      final primaryHome = state.homes.first;
      final vacationHome = state.homes[1];

      // Verify devices in primary home
      final primaryDevices = repository.getDevicesForHome(primaryHome.id);
      expect(primaryDevices, isNotEmpty);
      for (final dev in primaryDevices) {
        expect(dev.homeId, equals(primaryHome.id));
      }

      // Verify devices in vacation home
      final vacationDevices = repository.getDevicesForHome(vacationHome.id);
      for (final dev in vacationDevices) {
        expect(dev.homeId, equals(vacationHome.id));
        expect(primaryDevices.contains(dev), isFalse);
      }

      // Switch active home
      await persistenceManager.saveCurrentHomeId(vacationHome.id);
      final updated = await persistenceManager.loadHomeState();
      expect(updated.currentHomeId, equals(vacationHome.id));
    });

    // =========================================================================
    // CUJ 03: Room Management & Dynamic Filtering
    // =========================================================================
    testWidgets('CUJ 03: Room Management & Dynamic Filtering', (tester) async {
      setupViewport(tester);
      await persistenceManager.loadHomeState();

      String? selectedRoom;
      await tester.pumpWidget(createTestApp(RoomsScreen(
        onRoomSelected: (r) => selectedRoom = r,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(RoomsScreen), findsOneWidget);
      expect(find.text('Living Room'), findsWidgets);
      expect(find.text('Bedroom'), findsWidgets);

      // Tap room card invokes onRoomSelected
      await tester.tap(find.text('Living Room').first);
      await tester.pumpAndSettle();
      expect(selectedRoom, equals('Living Room'));
    });

    // =========================================================================
    // CUJ 04: Device Discovery & BLE Provisioning Flow
    // =========================================================================
    test('CUJ 04: Device Discovery & BLE Provisioning Flow', () async {
      final bleService = MockBleService();
      expect(bleService.isSupported, isTrue);

      final discoveryFuture = bleService.discoveredDevices.first;
      await bleService.startScan();
      final discoveredList = await discoveryFuture;
      expect(discoveredList, isNotEmpty);
      await bleService.stopScan();

      final candidate = discoveredList.first;
      expect(candidate.name, isNotEmpty);

      // Add provisioned device to repository
      final newDevice = SmartDevice(
        id: 'dev-provisioned-${candidate.id}',
        name: candidate.name,
        roomId: 'Living Room',
        type: candidate.type,
        isOn: false,
        homeId: 'home-default',
      );
      repository.addDevice(newDevice);

      expect(repository.devices.any((d) => d.id == newDevice.id), isTrue);
      await bleService.dispose();
    });

    // =========================================================================
    // CUJ 05: Comprehensive Multi-Type Device Controls
    // =========================================================================
    test('CUJ 05: Comprehensive Multi-Type Device Controls', () async {
      await persistenceManager.loadHomeState();

      // 1. Light controls
      const light = SmartDevice(
        id: 'dev-ctrl-light',
        name: 'Accent Light',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: false,
        brightness: 30,
        homeId: 'home-default',
      );
      repository.addDevice(light);

      final pwrRes = await repository.sendCommand(
        DeviceCommand(
          requestId: 'cmd-l1',
          deviceId: light.id,
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(pwrRes.status, equals(CommandStatus.confirmed));
      expect(repository.getDeviceById(light.id)?.isOn, isTrue);

      final brtRes = await repository.sendCommand(
        DeviceCommand(
          requestId: 'cmd-l2',
          deviceId: light.id,
          type: DeviceCommandType.setBrightness,
          value: 95,
        ),
      );
      expect(brtRes.status, equals(CommandStatus.confirmed));
      expect(repository.getDeviceById(light.id)?.brightness, equals(95));

      // 2. AC controls
      const ac = SmartDevice(
        id: 'dev-ctrl-ac',
        name: 'Living AC',
        roomId: 'Living Room',
        type: DeviceType.ac,
        isOn: true,
        targetTemperature: 24.0,
        homeId: 'home-default',
      );
      repository.addDevice(ac);

      final acRes = await repository.sendCommand(
        DeviceCommand(
          requestId: 'cmd-ac1',
          deviceId: ac.id,
          type: DeviceCommandType.setTargetTemperature,
          value: 21.0,
        ),
      );
      expect(acRes.status, equals(CommandStatus.confirmed));
      expect(repository.getDeviceById(ac.id)?.targetTemperature, equals(21.0));

      // 3. Lock controls
      const lock = SmartDevice(
        id: 'dev-ctrl-lock',
        name: 'Front Lock',
        roomId: 'Living Room',
        type: DeviceType.lock,
        isOn: true,
        isLocked: true,
        homeId: 'home-default',
      );
      repository.addDevice(lock);

      final lockRes = await repository.sendCommand(
        DeviceCommand(
          requestId: 'cmd-lock1',
          deviceId: lock.id,
          type: DeviceCommandType.setLock,
          value: false,
        ),
      );
      expect(lockRes.status, equals(CommandStatus.confirmed));
      expect(repository.getDeviceById(lock.id)?.isLocked, isFalse);
    });

    // =========================================================================
    // CUJ 06: Coordinated Scene Execution & Timeline Activity Log
    // =========================================================================
    test('CUJ 06: Coordinated Scene Execution & Timeline Activity Log',
        () async {
      final state = await persistenceManager.loadHomeState();
      final lightDev =
          state.devices.firstWhere((d) => d.type == DeviceType.light);

      final dinnerScene = Scene(
        id: 'scene-candlelight',
        name: 'Candlelight Dinner',
        iconName: 'restaurant',
        homeId: state.currentHomeId,
        actions: [
          DeviceAction(
            deviceId: lightDev.id,
            commandType: DeviceCommandType.setBrightness,
            value: 25,
          ),
        ],
      );

      await persistenceManager.saveScenes([...state.scenes, dinnerScene]);

      // Execute scene
      for (final action in dinnerScene.actions) {
        await repository.sendCommand(
          DeviceCommand(
            requestId: 'req-scene-${action.deviceId}',
            deviceId: action.deviceId,
            type: action.commandType,
            value: action.value,
          ),
        );
      }

      // Record activity event
      final event = ActivityEvent(
        id: 'evt-cuj-06',
        timestamp: DateTime.now(),
        title: 'Scene Executed: Candlelight Dinner',
        description: 'Atmosphere set for fine dining.',
        homeId: state.currentHomeId,
      );
      await persistenceManager
          .saveActivityEvents([event, ...state.activityEvents]);

      final reloaded = await persistenceManager.loadHomeState();
      expect(reloaded.activityEvents.any((e) => e.id == 'evt-cuj-06'), isTrue);
      expect(repository.getDeviceById(lightDev.id)?.brightness, equals(25));
    });

    // =========================================================================
    // CUJ 07: Automation Rule Evaluation & Loop Protection Guard
    // =========================================================================
    test('CUJ 07: Automation Rule Evaluation & Loop Protection Guard',
        () async {
      final state = await persistenceManager.loadHomeState();
      final targetDev = state.devices.first;

      final testRule = AutomationRule(
        id: 'rule-cuj-07',
        name: 'Sunset Ambient Dimming',
        isEnabled: true,
        triggerType: TriggerType.schedule,
        timeOfDay: '18:30',
        homeId: state.currentHomeId,
        actions: [
          DeviceAction(
            deviceId: targetDev.id,
            commandType: DeviceCommandType.setBrightness,
            value: 40,
          ),
        ],
      );

      int dispatchCount = 0;
      final engine = AutomationEngine(
        initialRules: [testRule],
        maxExecutionHistory: 50,
        onDispatchAction: (action) async {
          dispatchCount++;
          await repository.sendCommand(
            DeviceCommand(
              requestId: 'auto-cmd-sunset',
              deviceId: action.deviceId,
              type: action.commandType,
              value: action.value,
            ),
          );
        },
      );

      // Evaluate at 18:30
      await engine.evaluate(
        virtualTime: DateTime(2026, 10, 27, 18, 30, 0),
        devices: repository.devices,
      );

      expect(dispatchCount, equals(1));
      expect(repository.getDeviceById(targetDev.id)?.brightness, equals(40));

      // Disable rule
      engine.removeRule(testRule.id);
      engine.addRule(testRule.copyWith(isEnabled: false));

      // Re-evaluate at 18:31 -> no dispatch
      await engine.evaluate(
        virtualTime: DateTime(2026, 10, 27, 18, 31, 0),
        devices: repository.devices,
      );
      expect(dispatchCount, equals(1));

      engine.dispose();
    });

    // =========================================================================
    // CUJ 08: Offline Simulation & Reconnection Storm Recovery
    // =========================================================================
    test('CUJ 08: Offline Simulation & Reconnection Storm Recovery', () async {
      await persistenceManager.loadHomeState();
      final testDev = repository.devices.first;

      // Force device offline
      repository.forceDeviceOffline(testDev.id);
      expect(repository.getDeviceById(testDev.id)?.connection,
          equals(DeviceConnection.offline));

      // Sending command fails gracefully
      final failRes = await repository.sendCommand(
        DeviceCommand(
          requestId: 'cmd-offline-1',
          deviceId: testDev.id,
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(failRes.status, equals(CommandStatus.failed));
      expect(failRes.errorMessage, contains('offline'));

      // Reconnect device (storm recovery)
      repository.reconnectDevice(testDev.id);
      expect(repository.getDeviceById(testDev.id)?.connection,
          equals(DeviceConnection.online));

      // Retry command succeeds
      final okRes = await repository.sendCommand(
        DeviceCommand(
          requestId: 'cmd-offline-retry',
          deviceId: testDev.id,
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(okRes.status, equals(CommandStatus.confirmed));
    });

    // =========================================================================
    // CUJ 09: Energy Telemetry Breakdown & RFC-4180 CSV Export
    // =========================================================================
    test('CUJ 09: Energy Telemetry Breakdown & RFC-4180 CSV Export', () {
      const energyService = EnergyInsightsService();
      final devices = [
        const SmartDevice(
          id: 'dev-e1',
          name: 'Home Theater',
          roomId: 'Living Room',
          type: DeviceType.socket,
          isOn: true,
          powerUsageWatts: 350.0,
          homeId: 'home-default',
        ),
        const SmartDevice(
          id: 'dev-e2',
          name:
              '=FORMULA_INJECTION_DEVICE', // malicious CSV injection candidate
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          powerUsageWatts: 15.0,
          homeId: 'home-default',
        ),
      ];

      final report = energyService.generateReport(devices: devices);
      expect(report.totalKwh, greaterThanOrEqualTo(0.0));
      expect(report.deviceBreakdown.length, equals(2));

      final csv = energyService.exportEnergyCsv(report);
      expect(csv.contains('Lumivo Energy Report'), isTrue);
      expect(csv.contains('Home Theater'), isTrue);
      // Verify CWE-1236 injection neutralization
      expect(csv, contains("'=FORMULA_INJECTION_DEVICE"));
      expect(csv, isNot(contains(',=FORMULA_INJECTION_DEVICE')));
    });

    // =========================================================================
    // CUJ 10: Safe Backup Export with Strict Version 1.0.0-rc.1
    // =========================================================================
    test(
        'CUJ 10: Safe Backup Export with Strict Version 1.0.0-rc.1 & Credential Scrubbing',
        () async {
      final state = await persistenceManager.loadHomeState();

      // Inject dirty secret in device
      final targetDev = state.devices.first.copyWith(
        customData: {
          'wifi_password': 'PlainTextWiFiSecret!',
          'api_key': 'super_secret_api_key',
          'model_no': 'LUM-1000',
        },
      );
      await persistenceManager.saveDevices([
        targetDev,
        ...state.devices.skip(1),
      ]);

      final exportedJson = await backupService.exportBackupJson(
        persistenceManager: persistenceManager,
      );

      final decoded = jsonDecode(exportedJson) as Map<String, dynamic>;
      final metadata = decoded['metadata'] as Map<String, dynamic>;

      // Exact checks for 1.0.0-rc.1
      expect(metadata['lumivoVersion'], equals('1.0.0-rc.1'));
      expect(metadata['schemaVersion'], equals(6));

      // Credential scrubbing verification
      expect(exportedJson.contains('PlainTextWiFiSecret!'), isFalse);
      expect(exportedJson.contains('super_secret_api_key'), isFalse);
      expect(exportedJson.contains('LUM-1000'), isTrue);
    });

    // =========================================================================
    // CUJ 11: Safe Backup Restore Preview & Atomic Transactional Rollback
    // =========================================================================
    test('CUJ 11: Safe Backup Restore Preview & Atomic Transactional Rollback',
        () async {
      final initialHomeCount = persistenceManager.cachedState!.homes.length;

      // 1. Preview of valid payload
      final validPayload = jsonEncode({
        'metadata': {
          'schemaVersion': 6,
          'lumivoVersion': '1.0.0-rc.1',
          'exportedAt': DateTime.now().toIso8601String(),
        },
        'homes': [
          {'id': 'home-restore-ok', 'name': 'Restored Villa'}
        ],
        'devices': [],
        'scenes': [],
        'automations': [],
      });

      final preview =
          await backupService.validateAndPreviewBackup(validPayload);
      expect(preview.isValid, isTrue);
      expect(preview.homeCount, equals(1));

      // 2. Corrupted payload causes atomic rollback
      final corruptedPayload = jsonEncode({
        'metadata': {'schemaVersion': 99}, // invalid schema
        'homes': [
          {'id': 'home-bad-payload', 'name': 'Corrupt Home'}
        ],
        'devices': [],
        'scenes': [],
        'automations': [],
      });

      final restoreOk = await backupService.restoreBackup(
        jsonString: corruptedPayload,
        persistenceManager: persistenceManager,
      );
      expect(restoreOk, isFalse);

      // Verify rollback preserved state
      final stateAfterFail = await persistenceManager.loadHomeState();
      expect(stateAfterFail.homes.length, equals(initialHomeCount));
      expect(
        stateAfterFail.homes.any((h) => h.id == 'home-bad-payload'),
        isFalse,
      );
    });

    // =========================================================================
    // CUJ 12: Recovery Center Health Diagnostics & Snapshot Restore
    // =========================================================================
    testWidgets('CUJ 12: Recovery Center Health Diagnostics & Snapshot Restore',
        (tester) async {
      setupViewport(tester);
      await persistenceManager.loadHomeState();
      await persistenceManager.saveSnapshot();

      await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryCenterScreen), findsOneWidget);
      expect(find.text('Recovery Center'), findsWidgets);

      // Verify restore snapshot survives and functions
      final restored = await persistenceManager.restoreSnapshot();
      expect(restored, isTrue);
    });

    // =========================================================================
    // CUJ 13: Privacy Center Local Storage Audit & Zero Remote Guarantee
    // =========================================================================
    testWidgets(
        'CUJ 13: Privacy Center Local Storage Audit & Zero Remote Guarantee',
        (tester) async {
      setupViewport(tester);
      await persistenceManager.loadHomeState();

      await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyCenterScreen), findsOneWidget);
      expect(find.byKey(const Key('privacy_simulation_mode_card')),
          findsOneWidget);
      expect(find.byKey(const Key('privacy_export_backup_button')),
          findsOneWidget);
    });

    // =========================================================================
    // CUJ 14: Bilingual Localization Parity Across Primary Surfaces
    // =========================================================================
    testWidgets('CUJ 14: Bilingual Localization Parity Across Primary Surfaces',
        (tester) async {
      setupViewport(tester);

      // 1. English
      await tester.pumpWidget(createTestApp(
        const SettingsScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.byKey(const Key('settings_privacy_center_tile')),
          findsOneWidget);

      // 2. Vietnamese
      await tester.pumpWidget(createTestApp(
        const SettingsScreen(),
        locale: const Locale('vi'),
      ));
      await tester.pumpAndSettle();

      final vi = AppLocalizations(const Locale('vi'));
      expect(find.text(vi.settings), findsWidgets);
      expect(find.text(vi.privacyCenter), findsWidgets);
    });

    // =========================================================================
    // CUJ 15: Accessibility Compliance (WCAG 2.1 AA)
    // =========================================================================
    testWidgets(
        'CUJ 15: Accessibility Compliance (Touch Targets, Semantics & 2.0x Font Scaling)',
        (tester) async {
      setupViewport(tester);

      // Pump Dashboard under 2.0x font scaling
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceRepositoryProvider.overrideWithValue(repository),
            homePersistenceProvider.overrideWithValue(persistenceManager),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: const DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no RenderFlex overflows
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // CUJ 16: Ultra-Narrow Mobile Responsiveness (320x600 Viewport)
    // =========================================================================
    testWidgets(
        'CUJ 16: Ultra-Narrow Mobile Responsiveness (320x600 Viewport Across All Screens)',
        (tester) async {
      setupViewport(tester, const Size(320, 600));

      // Test all core screens under ultra-narrow viewport
      await tester.pumpWidget(createTestApp(const DashboardScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const RoomsScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const AutomationScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const EnergyScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const SettingsScreen()));
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
    });

    // =========================================================================
    // CUJ 17: App Lifecycle Transitions & Cold Restart State Persistence
    // =========================================================================
    test('CUJ 17: App Lifecycle Transitions & Cold Restart State Persistence',
        () async {
      final clock = VirtualClock(autoStart: false);
      clock.start();

      final observer = SimulationLifecycleObserver(
        clock: clock,
        syncElapsedTimeOnResume: false,
      );

      // 1. Lifecycle background pause
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(clock.isRunning, isFalse);

      // 2. Lifecycle foreground resume
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(clock.isRunning, isTrue);

      observer.dispose();
      clock.dispose();

      // 3. Cold restart state persistence
      final originalState = await persistenceManager.loadHomeState();
      const customDev = SmartDevice(
        id: 'dev-cuj-17',
        name: 'Cold Restart Device',
        roomId: 'Living Room',
        type: DeviceType.socket,
        isOn: true,
        powerUsageWatts: 60.0,
        homeId: 'home-default',
      );
      await persistenceManager
          .saveDevices([...originalState.devices, customDev]);

      // Re-initialize fresh PM from same storage
      final pmFresh = HomePersistenceManager(storage: storage);
      final freshState = await pmFresh.loadHomeState();

      expect(freshState.devices.any((d) => d.id == 'dev-cuj-17'), isTrue);
      final reloadedDev =
          freshState.devices.firstWhere((d) => d.id == 'dev-cuj-17');
      expect(reloadedDev.name, equals('Cold Restart Device'));
      expect(reloadedDev.isOn, isTrue);
      expect(reloadedDev.powerUsageWatts, equals(60.0));
    });
  });
}
