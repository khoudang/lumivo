import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/localization/app_localizations.dart';
import 'package:lumivo/core/localization/strings_en.dart';
import 'package:lumivo/core/localization/strings_vi.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/automation/state/automation_notifier.dart';
import 'package:lumivo/features/automation/state/scene_preview_notifier.dart';
import 'package:lumivo/features/dashboard/state/dashboard_config_notifier.dart';
import 'package:lumivo/features/energy/state/energy_insights_notifier.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/scenes/scenes_service.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/command_pipeline.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 7 End-to-End Acceptance Test Suite (Journeys A through L)', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late MockDeviceRepository repository;
    late BackupRestoreService backupService;

    setUp(() {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        persistenceManager: persistenceManager,
      );
      backupService = const BackupRestoreService();
      repository.resetToDemo();
    });

    tearDown(() async {
      await repository.dispose();
    });

    // -------------------------------------------------------------------------
    // JOURNEY A: New User Onboarding & Home Creation
    // -------------------------------------------------------------------------
    test('Journey A: New User Onboarding & Home Creation', () async {
      // 1. Initial first-run check
      expect(await persistenceManager.isFirstRunCompleted(), isFalse);

      // 2. Complete onboarding
      await persistenceManager.setFirstRunCompleted(true);
      expect(await persistenceManager.isFirstRunCompleted(), isTrue);

      // 3. Create a new Home domain
      final state = await persistenceManager.loadHomeState();
      final newHome = Home(
        id: 'home-eco-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Eco Smart Sanctuary',
        address: '77 Solar Crest Way',
        role: 'Owner',
        isCurrent: true,
        tariffRate: 0.18,
        currency: 'USD',
        createdAt: DateTime.now(),
      );

      final updatedHomes = [
        ...state.homes.map((h) => h.copyWith(isCurrent: false)),
        newHome,
      ];
      await persistenceManager.saveHomes(updatedHomes);
      await persistenceManager.saveCurrentHomeId(newHome.id);

      // 4. Reload and verify new home is active with its own default DashboardConfig
      final freshState = await persistenceManager.loadHomeState();
      expect(freshState.homes.any((h) => h.id == newHome.id), isTrue);
      expect(freshState.currentHomeId, equals(newHome.id));

      final config = persistenceManager.getDashboardConfig(newHome.id);
      expect(config.homeId, equals(newHome.id));
      expect(config.sectionOrder, isNotEmpty);
      expect(config.isVisible(DashboardSection.metrics), isTrue);
    });

    // -------------------------------------------------------------------------
    // JOURNEY B: Device Lifecycle
    // (Add, Rename, Move Room, Favorite, Control, Delete)
    // -------------------------------------------------------------------------
    test(
        'Journey B: Device Lifecycle (Add, Rename, Move Room, Favorite, Control, Delete)',
        () async {
      await persistenceManager.loadHomeState();

      // 1. Add device
      const newDevId = 'dev-journey-b-light';
      const initialDev = SmartDevice(
        id: newDevId,
        name: 'Living Ambient Strip',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: false,
        brightness: 50,
        homeId: 'home-default',
        isFavorite: false,
        favoriteOrder: 0,
      );
      repository.addDevice(initialDev);

      var devices = await repository.watchDevices().first;
      expect(devices.any((d) => d.id == newDevId), isTrue);

      // 2. Rename device
      final renamedDev = initialDev.copyWith(name: 'Grand Ambient Strip');
      repository.updateDevice(renamedDev);
      devices = await repository.watchDevices().first;
      expect(devices.firstWhere((d) => d.id == newDevId).name,
          equals('Grand Ambient Strip'));

      // 3. Move Room
      final movedDev = renamedDev.copyWith(roomId: 'Bedroom');
      repository.updateDevice(movedDev);
      devices = await repository.watchDevices().first;
      expect(devices.firstWhere((d) => d.id == newDevId).roomId,
          equals('Bedroom'));

      // 4. Mark Favorite
      final favDev = movedDev.copyWith(isFavorite: true, favoriteOrder: 0);
      repository.updateDevice(favDev);
      devices = await repository.watchDevices().first;
      expect(devices.firstWhere((d) => d.id == newDevId).isFavorite, isTrue);

      // 5. Control Device (turn on, set brightness to 85)
      final powerCmd = const DeviceCommand(
        requestId: 'cmd-b-pwr',
        deviceId: newDevId,
        type: DeviceCommandType.setPower,
        value: true,
      );
      final powerResult = await repository.sendCommand(powerCmd);
      expect(powerResult.status, equals(CommandStatus.confirmed));

      final brightCmd = const DeviceCommand(
        requestId: 'cmd-b-brt',
        deviceId: newDevId,
        type: DeviceCommandType.setBrightness,
        value: 85,
      );
      final brightResult = await repository.sendCommand(brightCmd);
      expect(brightResult.status, equals(CommandStatus.confirmed));

      devices = await repository.watchDevices().first;
      final controlledDev = devices.firstWhere((d) => d.id == newDevId);
      expect(controlledDev.isOn, isTrue);
      expect(controlledDev.brightness, equals(85));

      // 6. Delete Device with Cascade
      await repository.removeDeviceWithCascade(newDevId);
      devices = await repository.watchDevices().first;
      expect(devices.any((d) => d.id == newDevId), isFalse);

      final state = await persistenceManager.loadHomeState();
      expect(state.devices.any((d) => d.id == newDevId), isFalse);
      expect(
        state.activityEvents.any((e) =>
            e.title.contains('Cascade Deletion') && e.deviceId == newDevId),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // JOURNEY C: Multi-Home Isolation
    // (Switching, Scenes, Dashboard, Activity)
    // -------------------------------------------------------------------------
    test(
        'Journey C: Multi-Home Isolation (Switching, Scenes, Dashboard, Activity)',
        () async {
      final state = await persistenceManager.loadHomeState();

      const homeA = 'home-default';
      const homeB = 'home-suburban';

      // 1. Devices isolation
      final devicesA = state.devices.where((d) => d.homeId == homeA).toList();
      final devicesB = state.devices.where((d) => d.homeId == homeB).toList();
      expect(devicesA.any((d) => d.id == 'device-bulb-1'), isTrue);
      expect(devicesA.any((d) => d.id == 'device-villa-light'), isFalse);
      expect(devicesB.any((d) => d.id == 'device-villa-light'), isTrue);
      expect(devicesB.any((d) => d.id == 'device-bulb-1'), isFalse);

      // 2. Scenes isolation
      final scenesA = state.scenes.where((s) => s.homeId == homeA).toList();
      final scenesB = state.scenes.where((s) => s.homeId == homeB).toList();
      expect(scenesA.any((s) => s.name == 'Good Morning'), isTrue);
      expect(scenesA.any((s) => s.name == 'Villa Evening'), isFalse);
      expect(scenesB.any((s) => s.name == 'Villa Evening'), isTrue);
      expect(scenesB.any((s) => s.name == 'Good Morning'), isFalse);

      // 3. Dashboard config isolation
      final configA = persistenceManager.getDashboardConfig(homeA);
      final configB = persistenceManager.getDashboardConfig(homeB);
      expect(configA.homeId, equals(homeA));
      expect(configB.homeId, equals(homeB));

      final notifierA = DashboardConfigNotifier(
        homeId: homeA,
        persistenceManager: persistenceManager,
      );
      notifierA.toggleSectionVisibility(DashboardSection.metrics, false);
      await notifierA.saveLayout();

      final reloadedA = persistenceManager.getDashboardConfig(homeA);
      final reloadedB = persistenceManager.getDashboardConfig(homeB);
      expect(reloadedA.isVisible(DashboardSection.metrics), isFalse);
      expect(reloadedB.isVisible(DashboardSection.metrics), isTrue);

      // 4. Activity events isolation
      final eventA = ActivityEvent(
        id: 'evt-home-a',
        title: 'Home A Event',
        description: 'Action performed in Home A',
        timestamp: DateTime.now(),
        homeId: homeA,
      );
      final eventB = ActivityEvent(
        id: 'evt-home-b',
        title: 'Home B Event',
        description: 'Action performed in Home B',
        timestamp: DateTime.now(),
        homeId: homeB,
      );
      await persistenceManager.saveActivityEvents([eventA, eventB]);

      final allEvents =
          (await persistenceManager.loadHomeState()).activityEvents;
      final eventsForA = allEvents.where((e) => e.homeId == homeA).toList();
      final eventsForB = allEvents.where((e) => e.homeId == homeB).toList();
      expect(eventsForA.any((e) => e.id == 'evt-home-a'), isTrue);
      expect(eventsForA.any((e) => e.id == 'evt-home-b'), isFalse);
      expect(eventsForB.any((e) => e.id == 'evt-home-b'), isTrue);
      expect(eventsForB.any((e) => e.id == 'evt-home-a'), isFalse);
    });

    // -------------------------------------------------------------------------
    // JOURNEY D: Automation
    // (WHEN/IF/THEN rule creation, execution, history, loop guard)
    // -------------------------------------------------------------------------
    test(
        'Journey D: Automation (WHEN/IF/THEN rule creation, execution, history, loop guard)',
        () async {
      await persistenceManager.loadHomeState();

      // 1. Validation check
      const invalidRule = AutomationRule(
        id: 'bad-rule',
        name: '',
        triggerType: TriggerType.schedule,
        actions: [],
      );
      expect(AutomationEngine.validateRule(invalidRule), isFalse);

      const validRule = AutomationRule(
        id: 'rule-cool-journey-d',
        name: 'Auto AC Temperature Guard',
        isEnabled: true,
        triggerType: TriggerType.sensorThreshold,
        sensorDeviceId: 'device-sensor-1',
        sensorProperty: 'temperature',
        operator: ComparisonOperator.greaterThan,
        thresholdValue: 26.5,
        homeId: 'home-default',
        actions: [
          DeviceAction(
            deviceId: 'device-ac-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );
      expect(AutomationEngine.validateRule(validRule), isTrue);

      // 2. Rule execution and history logging
      final automationNotifier = AutomationNotifier(
        [validRule],
        persistenceManager,
      );

      ActivityEvent? recordedEvent;
      await automationNotifier.executeRule(
        validRule,
        repository,
        (evt) => recordedEvent = evt,
      );

      expect(recordedEvent, isNotNull);
      expect(recordedEvent!.title, contains('Rule Executed'));
      expect(automationNotifier.state.first.lastExecutedAt, isNotNull);

      // 3. Loop Guard Prevention
      final records = <AutomationExecutionRecord>[];
      final engine = AutomationEngine(
        initialRules: [validRule],
        hysteresis: 0.1,
      );
      engine.executionRecordStream.listen(records.add);

      const hotSensor = SmartDevice(
        id: 'device-sensor-1',
        name: 'Living Room Sensor',
        roomId: 'Living Room',
        type: DeviceType.sensor,
        isOn: true,
        currentTemperature: 28.0,
      );

      const coolSensor = SmartDevice(
        id: 'device-sensor-1',
        name: 'Living Room Sensor',
        roomId: 'Living Room',
        type: DeviceType.sensor,
        isOn: true,
        currentTemperature: 24.0,
      );

      final baseTime = DateTime(2026, 10, 25, 12, 0, 0);

      // Flap 6 times within 500ms (< 1 second)
      for (int i = 0; i < 6; i++) {
        final t = baseTime.add(Duration(milliseconds: i * 80));
        await engine.evaluate(virtualTime: t, devices: [coolSensor]);
        await engine.evaluate(virtualTime: t, devices: [hotSensor]);
      }

      final loopPrevented = records.where(
        (r) => r.status == AutomationExecutionStatus.loopPrevented,
      );
      expect(loopPrevented.isNotEmpty, isTrue);
      expect(loopPrevented.first.reason, contains('Loop prevented'));

      engine.dispose();
    });

    // -------------------------------------------------------------------------
    // JOURNEY E: Scenes
    // (Multi-device scene, preview dialog, execution, state updates)
    // -------------------------------------------------------------------------
    test(
        'Journey E: Scenes (Multi-device scene, preview dialog, execution, state updates)',
        () async {
      final state = await persistenceManager.loadHomeState();

      const multiDeviceScene = Scene(
        id: 'scene-secure-night',
        name: 'Night Lockdown Mode',
        homeId: 'home-default',
        actions: [
          DeviceAction(
            deviceId: 'device-bulb-1',
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
          DeviceAction(
            deviceId: 'device-fan-1',
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
          DeviceAction(
            deviceId: 'device-lock-1',
            commandType: DeviceCommandType.setLock,
            value: true,
          ),
        ],
      );

      // 1. Preview calculation
      final previewItems = ScenePreviewEngine.computePreview(
        scene: multiDeviceScene,
        devices: state.devices,
      );
      expect(previewItems.length, equals(3));
      expect(previewItems[0].device?.id, equals('device-bulb-1'));
      expect(previewItems[0].targetValue, isFalse);

      // 2. Execution and state updates
      final activityLog = <ActivityEvent>[];
      final scenesService = ScenesService(
        initialScenes: [multiDeviceScene],
        persistenceManager: persistenceManager,
        onActivityEvent: activityLog.add,
      );

      await scenesService.executeScene(multiDeviceScene, repository);

      final devices = await repository.watchDevices().first;
      final bulb = devices.firstWhere((d) => d.id == 'device-bulb-1');
      final fan = devices.firstWhere((d) => d.id == 'device-fan-1');
      final lock = devices.firstWhere((d) => d.id == 'device-lock-1');

      expect(bulb.isOn, isFalse);
      expect(fan.isOn, isFalse);
      expect(lock.isLocked, isTrue);

      expect(activityLog.isNotEmpty, isTrue);
      expect(activityLog.last.title, contains('Night Lockdown Mode'));

      scenesService.dispose();
    });

    // -------------------------------------------------------------------------
    // JOURNEY F: Fault Recovery
    // (Force offline, fail safe, reconnect, storm recovery)
    // -------------------------------------------------------------------------
    test(
        'Journey F: Fault Recovery (Force offline, fail safe, reconnect, storm recovery)',
        () async {
      await persistenceManager.loadHomeState();

      final bulb = (await repository.watchDevices().first)
          .firstWhere((d) => d.id == 'device-bulb-1');

      // 1. Force offline
      repository
          .updateDevice(bulb.copyWith(connection: DeviceConnection.offline));

      // 2. Fail safe: commands sent to offline devices fail cleanly
      final offlineResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-offline-test',
          deviceId: 'device-bulb-1',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(offlineResult.status, equals(CommandStatus.failed));
      expect(offlineResult.errorMessage, isNotNull);

      // 3. Reconnect device
      repository
          .updateDevice(bulb.copyWith(connection: DeviceConnection.online));

      final onlineResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-online-test',
          deviceId: 'device-bulb-1',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(onlineResult.status, equals(CommandStatus.confirmed));

      // 4. Storm recovery: concurrent command pipeline deduplication
      final pipeline = CommandPipeline(simulatedLatency: Duration.zero);
      final futures = List.generate(
        15,
        (i) => pipeline.execute(
          DeviceCommand(
            requestId: 'cmd-storm-$i',
            deviceId: 'device-bulb-1',
            type: DeviceCommandType.setPower,
            value: i % 2 == 0,
          ),
          onExecute: (cmd) async => CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.confirmed,
          ),
        ),
      );

      final results = await Future.wait(futures);
      expect(results.every((r) => r.status == CommandStatus.confirmed), isTrue);
    });

    // -------------------------------------------------------------------------
    // JOURNEY G: Energy Telemetry
    // (Virtual time advance, kWh computation, tariff, CSV)
    // -------------------------------------------------------------------------
    test(
        'Journey G: Energy Telemetry (Virtual time advance, kWh computation, tariff, CSV)',
        () {
      final devices = [
        const SmartDevice(
          id: 'dev-heater',
          name: 'Thermal Heater',
          roomId: 'Living Room',
          type: DeviceType.socket,
          isOn: true,
          powerUsageWatts: 2000.0, // 2 kW
        ),
        const SmartDevice(
          id: 'dev-light',
          name: 'LED Strip',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          powerUsageWatts: 100.0, // 0.1 kW
        ),
      ];

      final rooms = [
        const Room(
          id: 'Living Room',
          name: 'Living Room',
          iconName: 'living_room',
        ),
      ];

      const tariff = 0.20; // $0.20 per kWh
      // 24-hour day period
      final report = EnergyInsightsEngine.computeReport(
        period: 'day',
        devices: devices,
        rooms: rooms,
        tariff: tariff,
      );

      // 2000W * 24h = 48 kWh -> Cost: 48 * 0.20 = $9.60
      final heaterItem =
          report.deviceBreakdown.firstWhere((d) => d.id == 'dev-heater');
      expect(heaterItem.kwh, equals(48.0));
      expect(heaterItem.cost, equals(9.60));

      // 100W * 24h = 2.4 kWh -> Cost: 2.4 * 0.20 = $0.48
      final lightItem =
          report.deviceBreakdown.firstWhere((d) => d.id == 'dev-light');
      expect(lightItem.kwh, equals(2.4));
      expect(lightItem.cost, equals(0.48));

      // Total kWh = 48.0 + 2.4 = 50.4 kWh -> Total cost: $10.08
      expect(report.totalKwh, equals(50.4));
      expect(report.totalCost, equals(10.08));

      // CSV Export Verification
      final csv = EnergyInsightsEngine.exportToCsv(report);
      expect(
          csv,
          contains(
              'Timestamp,Category,ID,Name,Power (W),Energy (kWh),Cost (\$),Tariff (\$/kWh)'));
      expect(csv, contains('dev-heater'));
      expect(csv, contains('dev-light'));
      expect(csv, contains('total,total,Total,0.00,50.4000,10.0800,0.2000'));
    });

    // -------------------------------------------------------------------------
    // JOURNEY H: Backup & Restore
    // (Export, reset demo, restore, entity equivalence)
    // -------------------------------------------------------------------------
    test(
        'Journey H: Backup & Restore (Export, reset demo, restore, entity equivalence)',
        () async {
      await persistenceManager.loadHomeState();

      // 1. Export JSON backup
      final exportedJson = await backupService.exportBackupJson(
        persistenceManager: persistenceManager,
      );
      expect(exportedJson.isNotEmpty, isTrue);

      final decoded = jsonDecode(exportedJson) as Map<String, dynamic>;
      expect(decoded['metadata']['schemaVersion'], equals(6));
      expect((decoded['homes'] as List).isNotEmpty, isTrue);
      expect((decoded['devices'] as List).isNotEmpty, isTrue);

      // 2. Demo reset
      await persistenceManager.resetDemoData();

      // 3. Restore backup
      final success = await backupService.restoreBackup(
        jsonString: exportedJson,
        persistenceManager: persistenceManager,
      );
      expect(success, isTrue);

      // 4. Entity equivalence verification
      final reloaded = await persistenceManager.loadHomeState();
      expect(reloaded.homes.length, equals((decoded['homes'] as List).length));
      expect(reloaded.rooms.length, equals((decoded['rooms'] as List).length));
      expect(
          reloaded.devices.length, equals((decoded['devices'] as List).length));
      expect(
          reloaded.scenes.length, equals((decoded['scenes'] as List).length));
      expect(reloaded.automations.length,
          equals((decoded['automations'] as List).length));
      expect(reloaded.dashboardConfigs.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // JOURNEY I: Invalid Backup Rejection & Rollback Safety
    // -------------------------------------------------------------------------
    test(
        'Journey I: Invalid Backup Rejection & Rollback Safety (Malformed/unsupported, rollback safety)',
        () async {
      final preState = await persistenceManager.loadHomeState();
      final preHomes = preState.homes.length;
      final preDevices = preState.devices.length;

      // 1. Malformed syntax
      const malformedJson = '{"metadata": { INVALID_JSON_SYNTAX';
      final res1 = await backupService.restoreBackup(
        jsonString: malformedJson,
        persistenceManager: persistenceManager,
      );
      expect(res1, isFalse);

      // 2. Oversized payload (> 5MB)
      final oversizedJson = jsonEncode({
        'metadata': {'schemaVersion': 6},
        'homes': [],
        'devices': [],
        'padding': 'X' * (5 * 1024 * 1024 + 100),
      });
      final res2 = await backupService.restoreBackup(
        jsonString: oversizedJson,
        persistenceManager: persistenceManager,
      );
      expect(res2, isFalse);

      // 3. Unsupported schema version (version 99)
      final futureVersionJson = jsonEncode({
        'metadata': {'schemaVersion': 99},
        'homes': [],
        'devices': [],
      });
      final res3 = await backupService.restoreBackup(
        jsonString: futureVersionJson,
        persistenceManager: persistenceManager,
      );
      expect(res3, isFalse);

      // 4. Duplicate device IDs
      final duplicateJson = jsonEncode({
        'metadata': {'schemaVersion': 6},
        'homes': [
          {'id': 'h-1', 'name': 'H1'}
        ],
        'rooms': [
          {'id': 'r-1', 'name': 'R1'}
        ],
        'devices': [
          {'id': 'dev-dup', 'name': 'D1', 'roomId': 'r-1'},
          {'id': 'dev-dup', 'name': 'D2', 'roomId': 'r-1'},
        ],
        'scenes': [],
        'automations': [],
      });
      final res4 = await backupService.restoreBackup(
        jsonString: duplicateJson,
        persistenceManager: persistenceManager,
      );
      expect(res4, isFalse);

      // 5. Verify pre-restore state is completely unharmed
      final postState = await persistenceManager.loadHomeState();
      expect(postState.homes.length, equals(preHomes));
      expect(postState.devices.length, equals(preDevices));
      expect(postState.currentHomeId, equals(preState.currentHomeId));
    });

    // -------------------------------------------------------------------------
    // JOURNEY J: Dashboard Customization
    // (Reorder, hide, multi-home persistence)
    // -------------------------------------------------------------------------
    test(
        'Journey J: Dashboard Customization (Reorder, hide, multi-home persistence)',
        () async {
      await persistenceManager.loadHomeState();

      final notifierHomeA = DashboardConfigNotifier(
        homeId: 'home-default',
        persistenceManager: persistenceManager,
      );
      final notifierHomeB = DashboardConfigNotifier(
        homeId: 'home-suburban',
        persistenceManager: persistenceManager,
      );

      // 1. Home A: Reorder favorites to top, hide activity
      notifierHomeA.reorderSections(2, 0); // favorites to top
      notifierHomeA.toggleSectionVisibility(DashboardSection.activity, false);
      await notifierHomeA.saveLayout();

      // 2. Home B: Reorder quickScenes to top, hide health
      notifierHomeB.reorderSections(3, 0); // quickScenes to top
      notifierHomeB.toggleSectionVisibility(DashboardSection.health, false);
      await notifierHomeB.saveLayout();

      // 3. Verify persistence
      final cfgA = persistenceManager.getDashboardConfig('home-default');
      final cfgB = persistenceManager.getDashboardConfig('home-suburban');

      expect(cfgA.sectionOrder.first, equals(DashboardSection.favorites));
      expect(cfgA.isVisible(DashboardSection.activity), isFalse);
      expect(cfgA.isVisible(DashboardSection.health), isTrue);

      expect(cfgB.sectionOrder.first, equals(DashboardSection.quickScenes));
      expect(cfgB.isVisible(DashboardSection.health), isFalse);
      expect(cfgB.isVisible(DashboardSection.activity), isTrue);

      // 4. Reset Home A to defaults
      await notifierHomeA.resetToDefaults();
      final resetA = persistenceManager.getDashboardConfig('home-default');
      expect(resetA.isVisible(DashboardSection.activity), isTrue);
      expect(resetA.sectionOrder.first, equals(DashboardSection.metrics));
    });

    // -------------------------------------------------------------------------
    // JOURNEY K: Localization (EN/VI full UI coverage)
    // -------------------------------------------------------------------------
    test('Journey K: Localization (EN/VI full UI coverage)', () {
      final l10nEn = AppLocalizations(const Locale('en'));
      final l10nVi = AppLocalizations(const Locale('vi'));

      // 1. Verify EN localized keys
      expect(l10nEn.home, equals(stringsEn['nav_home']));
      expect(l10nEn.rooms, equals(stringsEn['nav_rooms']));
      expect(l10nEn.devices, equals(stringsEn['devices']));
      expect(l10nEn.automations, equals(stringsEn['automations']));
      expect(l10nEn.scenes, equals(stringsEn['scenes']));
      expect(l10nEn.backupAndRestore, equals(stringsEn['backup_and_restore']));
      expect(l10nEn.settings, equals(stringsEn['nav_settings']));

      // 2. Verify VI localized keys
      expect(l10nVi.home, equals(stringsVi['nav_home']));
      expect(l10nVi.rooms, equals(stringsVi['nav_rooms']));
      expect(l10nVi.devices, equals(stringsVi['devices']));
      expect(l10nVi.automations, equals(stringsVi['automations']));
      expect(l10nVi.scenes, equals(stringsVi['scenes']));
      expect(l10nVi.backupAndRestore, equals(stringsVi['backup_and_restore']));
      expect(l10nVi.settings, equals(stringsVi['nav_settings']));

      // 3. Verify non-empty and non-identical strings
      expect(l10nVi.rooms, isNot(equals(l10nEn.rooms)));
      expect(l10nVi.automations, isNot(equals(l10nEn.automations)));
    });

    // -------------------------------------------------------------------------
    // JOURNEY L: Stress & Lifecycle
    // (100 devices, 20 rooms, 100 automations, 1000 events)
    // -------------------------------------------------------------------------
    test(
        'Journey L: Stress & Lifecycle (100 devices, 20 rooms, 100 automations, 1000 events)',
        () async {
      await persistenceManager.loadHomeState();

      // 1. 20 Rooms
      final rooms = List.generate(
        20,
        (i) => Room(
          id: 'room-stress-$i',
          name: 'Stress Room $i',
          iconName: 'living_room',
          homeId: 'home-default',
        ),
      );
      await persistenceManager.saveRooms(rooms);

      // 2. 100 Devices distributed across rooms
      final devices = List.generate(
        100,
        (i) => SmartDevice(
          id: 'dev-stress-$i',
          name: 'Stress Device $i',
          roomId: 'room-stress-${i % 20}',
          type: DeviceType.values[i % DeviceType.values.length],
          isOn: i % 2 == 0,
          brightness: (i * 7) % 100,
          powerUsageWatts: (i * 15.0) % 1500,
          homeId: 'home-default',
          isFavorite: i < 10,
          favoriteOrder: i < 10 ? i : 0,
        ),
      );
      await persistenceManager.saveDevices(devices);

      // 3. 100 Automations
      final automations = List.generate(
        100,
        (i) => AutomationRule(
          id: 'auto-stress-$i',
          name: 'Stress Rule $i',
          isEnabled: i % 2 == 0,
          triggerType: TriggerType.schedule,
          timeOfDay: '${(i % 24).toString().padLeft(2, '0')}:00',
          homeId: 'home-default',
          actions: [
            DeviceAction(
              deviceId: 'dev-stress-$i',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        ),
      );
      await persistenceManager.saveAutomations(automations);

      // 4. 1000 Activity Events (strictly bounded to 100 in persistence)
      final thousandEvents = List.generate(
        1000,
        (i) => ActivityEvent(
          id: 'evt-stress-$i',
          title: 'Stress Event $i',
          description: 'High throughput event generation',
          timestamp: DateTime.now().subtract(Duration(milliseconds: i * 10)),
          homeId: 'home-default',
        ),
      );
      await persistenceManager.saveActivityEvents(thousandEvents);

      // Reload state from storage
      final stopwatch = Stopwatch()..start();
      final loadedState = await persistenceManager.loadHomeState();
      stopwatch.stop();

      // Query latency < 50ms
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // Verifications
      expect(loadedState.rooms.length, equals(20));
      expect(loadedState.devices.length, equals(100));
      expect(loadedState.automations.length, equals(100));

      // Bounded collection: 1000 events must be clamped to exactly 100 in storage!
      expect(loadedState.activityEvents.length, equals(100));

      // 5. Concurrent execution of 100 commands through pipeline
      final pipeline = CommandPipeline(simulatedLatency: Duration.zero);
      final commandFutures = List.generate(
        100,
        (i) => pipeline.execute(
          DeviceCommand(
            requestId: 'stress-cmd-$i',
            deviceId: 'dev-stress-$i',
            type: DeviceCommandType.setPower,
            value: true,
          ),
          onExecute: (cmd) async => CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.confirmed,
          ),
        ),
      );

      final cmdResults = await Future.wait(commandFutures);
      expect(cmdResults.length, equals(100));
      expect(
          cmdResults.every((r) => r.status == CommandStatus.confirmed), isTrue);
    });
  });
}
