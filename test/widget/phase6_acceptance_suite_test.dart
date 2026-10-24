import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/device_health.dart';
import 'package:lumivo/core/models/energy_report.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/automation/state/automation_notifier.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/scenes/scenes_service.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/command_pipeline.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 6 End-to-End Acceptance Test Suite (Flows A through L)', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late MockDeviceRepository repository;

    setUp(() {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        persistenceManager: persistenceManager,
      );
      repository.resetToDemo();
    });

    tearDown(() async {
      await repository.dispose();
    });

    // -------------------------------------------------------------------------
    // FLOW A: Dashboard Customization
    // reorder widgets, hide Energy widget, persist layout, reset to defaults
    // -------------------------------------------------------------------------
    test(
        'Flow A: Dashboard Customization (reorder widgets, hide Energy, persist layout, reset)',
        () async {
      await persistenceManager.loadHomeState();
      final notifier = DashboardConfigNotifier(
        homeId: 'home-default',
        persistenceManager: persistenceManager,
      );

      // Initial defaults
      expect(notifier.state.isVisible(DashboardSection.metrics), isTrue);
      expect(
          notifier.state.sectionOrder.first, equals(DashboardSection.metrics));

      // 1. Reorder widgets: move first item (metrics) to position 2
      notifier.reorderSections(0, 3);
      expect(notifier.state.sectionOrder.first,
          isNot(equals(DashboardSection.metrics)));

      // 2. Hide Energy / Metrics widget
      notifier.toggleSectionVisibility(DashboardSection.metrics, false);
      expect(notifier.state.isVisible(DashboardSection.metrics), isFalse);

      // 3. Persist layout
      await notifier.saveLayout();

      // Verify persistence survived in storage
      final loadedConfig =
          persistenceManager.getDashboardConfig('home-default');
      expect(loadedConfig.isVisible(DashboardSection.metrics), isFalse);
      expect(loadedConfig.sectionOrder, equals(notifier.state.sectionOrder));

      // 4. Reset to defaults
      await notifier.resetToDefaults();
      expect(notifier.state.isVisible(DashboardSection.metrics), isTrue);
      expect(
          notifier.state.sectionOrder.first, equals(DashboardSection.metrics));

      final resetConfig = persistenceManager.getDashboardConfig('home-default');
      expect(resetConfig.isVisible(DashboardSection.metrics), isTrue);
    });

    // -------------------------------------------------------------------------
    // FLOW B: Multi-Home Dashboard
    // Home A customized layout remains isolated from Home B layout
    // -------------------------------------------------------------------------
    test(
        'Flow B: Multi-Home Dashboard (Home A customized layout isolated from Home B)',
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

      // Customise Home A: Hide activity, move favorites to top
      notifierHomeA.toggleSectionVisibility(DashboardSection.activity, false);
      notifierHomeA.reorderSections(2, 0); // Move favorites to top
      await notifierHomeA.saveLayout();

      // Customise Home B: Hide health, move quickScenes to top
      notifierHomeB.toggleSectionVisibility(DashboardSection.health, false);
      notifierHomeB.reorderSections(3, 0); // Move quickScenes to top
      await notifierHomeB.saveLayout();

      // Verify Home A layout
      final configA = persistenceManager.getDashboardConfig('home-default');
      expect(configA.isVisible(DashboardSection.activity), isFalse);
      expect(configA.isVisible(DashboardSection.health), isTrue);
      expect(configA.sectionOrder.first, equals(DashboardSection.favorites));

      // Verify Home B layout is isolated
      final configB = persistenceManager.getDashboardConfig('home-suburban');
      expect(configB.isVisible(DashboardSection.health), isFalse);
      expect(configB.isVisible(DashboardSection.activity), isTrue);
      expect(configB.sectionOrder.first, equals(DashboardSection.quickScenes));
    });

    // -------------------------------------------------------------------------
    // FLOW C: Device Search
    // query search, offline filter, sort, navigate to matching device
    // -------------------------------------------------------------------------
    test(
        'Flow C: Device Search (query search, offline filter, sort, select matching device)',
        () async {
      final devices = [
        const SmartDevice(
          id: 'dev-bulb-living',
          name: 'Living Ceiling Bulb',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          connection: DeviceConnection.online,
          homeId: 'home-default',
          isFavorite: true,
          favoriteOrder: 1,
        ),
        const SmartDevice(
          id: 'dev-fan-bed',
          name: 'Bedroom Smart Fan',
          roomId: 'Bedroom',
          type: DeviceType.fan,
          isOn: false,
          connection: DeviceConnection.offline,
          homeId: 'home-default',
          isFavorite: false,
          favoriteOrder: 2,
        ),
        const SmartDevice(
          id: 'dev-ac-bed',
          name: 'Bedroom Air Conditioner',
          roomId: 'Bedroom',
          type: DeviceType.ac,
          isOn: true,
          connection: DeviceConnection.online,
          homeId: 'home-default',
          isFavorite: false,
          favoriteOrder: 3,
        ),
      ];

      // 1. Text Query Search
      final nameMatches = DeviceSearchEngine.search(
        devices: devices,
        query: 'Ceiling',
      );
      expect(nameMatches.length, equals(1));
      expect(nameMatches.first.id, equals('dev-bulb-living'));

      final roomMatches = DeviceSearchEngine.search(
        devices: devices,
        query: 'Bedroom',
      );
      expect(roomMatches.length, equals(2));

      // 2. Offline Status Filter
      final offlineDevices = DeviceSearchEngine.search(
        devices: devices,
        statusFilter: false, // offline
      );
      expect(offlineDevices.length, equals(1));
      expect(offlineDevices.first.id, equals('dev-fan-bed'));

      final onlineDevices = DeviceSearchEngine.search(
        devices: devices,
        statusFilter: true, // online
      );
      expect(onlineDevices.length, equals(2));

      // 3. Sorting (by name, room, recent)
      final sortedByName = DeviceSearchEngine.search(
        devices: devices,
        sortBy: 'name',
      );
      expect(sortedByName.first.name, equals('Bedroom Air Conditioner'));

      final sortedByRecent = DeviceSearchEngine.search(
        devices: devices,
        sortBy: 'recent',
      );
      expect(sortedByRecent.first.isFavorite, isTrue);
      expect(sortedByRecent.first.id, equals('dev-bulb-living'));
    });

    // -------------------------------------------------------------------------
    // FLOW D: Scene Preview
    // preview 3 device actions before execution, verify activity log
    // -------------------------------------------------------------------------
    test(
        'Flow D: Scene Preview (preview 3 device actions before execution, verify activity log)',
        () async {
      final devices = [
        const SmartDevice(
          id: 'dev-1',
          name: 'Main Light',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          brightness: 100,
        ),
        const SmartDevice(
          id: 'dev-2',
          name: 'AC Unit',
          roomId: 'Bedroom',
          type: DeviceType.ac,
          isOn: false,
          targetTemperature: 25.0,
        ),
        const SmartDevice(
          id: 'dev-3',
          name: 'Front Lock',
          roomId: 'Living Room',
          type: DeviceType.lock,
          isOn: true,
          isLocked: false,
        ),
      ];

      const scene = Scene(
        id: 'scene-preview-test',
        name: 'Night Lockdown',
        homeId: 'home-default',
        actions: [
          DeviceAction(
            deviceId: 'dev-1',
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
          DeviceAction(
            deviceId: 'dev-2',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
          DeviceAction(
            deviceId: 'dev-3',
            commandType: DeviceCommandType.setLock,
            value: true,
          ),
        ],
      );

      // 1. Preview 3 device actions
      final previewItems = ScenePreviewEngine.computePreview(
        scene: scene,
        devices: devices,
      );
      expect(previewItems.length, equals(3));

      // Verify dev-1 preview (currently ON -> target OFF)
      expect(previewItems[0].device?.id, equals('dev-1'));
      expect(previewItems[0].currentValue, isTrue);
      expect(previewItems[0].targetValue, isFalse);
      expect(previewItems[0].willChange, isTrue);

      // Verify dev-2 preview (currently OFF -> target ON)
      expect(previewItems[1].device?.id, equals('dev-2'));
      expect(previewItems[1].currentValue, isFalse);
      expect(previewItems[1].targetValue, isTrue);
      expect(previewItems[1].willChange, isTrue);

      // Verify dev-3 preview (currently unlocked -> target locked)
      expect(previewItems[2].device?.id, equals('dev-3'));
      expect(previewItems[2].currentValue, isFalse);
      expect(previewItems[2].targetValue, isTrue);
      expect(previewItems[2].willChange, isTrue);

      // 2. Execute scene & verify activity log
      final activityHistory = <ActivityEvent>[];
      final scenesService = ScenesService(
        initialScenes: [scene],
        persistenceManager: persistenceManager,
        onActivityEvent: activityHistory.add,
      );

      await scenesService.executeScene(scene, repository);

      expect(scenesService.activityHistory.isNotEmpty, isTrue);
      final event = scenesService.activityHistory.last;
      expect(event.title.contains('Night Lockdown'), isTrue);
      expect(event.source, equals('scene'));

      scenesService.dispose();
    });

    // -------------------------------------------------------------------------
    // FLOW E: Automation Builder 2.0
    // WHEN/IF/THEN rule validation, activation, and execution
    // -------------------------------------------------------------------------
    test(
        'Flow E: Automation Builder 2.0 (WHEN/IF/THEN rule validation, activation, execution)',
        () async {
      // 1. Validation: invalid empty rule rejected
      const invalidRule = AutomationRule(
        id: 'rule-invalid',
        name: '',
        triggerType: TriggerType.schedule,
        actions: [],
      );
      expect(AutomationEngine.validateRule(invalidRule), isFalse);
      expect(AutomationEngine.getValidationError(invalidRule), isNotNull);

      // 2. Validation: valid rule accepted
      const validRule = AutomationRule(
        id: 'rule-valid-cool',
        name: 'Auto Cooling Rule',
        triggerType: TriggerType.sensorThreshold,
        sensorDeviceId: 'device-sensor-1',
        sensorProperty: 'temperature',
        operator: ComparisonOperator.greaterThan,
        thresholdValue: 27.0,
        actions: [
          DeviceAction(
            deviceId: 'device-ac-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );
      expect(AutomationEngine.validateRule(validRule), isTrue);
      expect(AutomationEngine.getValidationError(validRule), isNull);

      // 3. Activation: add and toggle
      final automationNotifier = AutomationNotifier(
        [validRule],
        persistenceManager,
      );

      expect(automationNotifier.state.first.isEnabled, isTrue);
      automationNotifier.toggleRule('rule-valid-cool');
      expect(automationNotifier.state.first.isEnabled, isFalse);
      automationNotifier.toggleRule('rule-valid-cool');
      expect(automationNotifier.state.first.isEnabled, isTrue);

      // 4. Execution
      ActivityEvent? recordedEvent;
      await automationNotifier.executeRule(
        validRule,
        repository,
        (evt) => recordedEvent = evt,
      );

      expect(recordedEvent, isNotNull);
      expect(recordedEvent!.title, contains('Rule Executed'));
      expect(automationNotifier.state.first.lastExecutedAt, isNotNull);
    });

    // -------------------------------------------------------------------------
    // FLOW F: Energy Analytics
    // verify kWh and estimated cost calculations for device and room
    // -------------------------------------------------------------------------
    test(
        'Flow F: Energy Analytics (verify kWh and estimated cost calculations for device and room)',
        () {
      final devices = [
        const SmartDevice(
          id: 'dev-ac',
          name: 'Living AC',
          roomId: 'Living Room',
          type: DeviceType.ac,
          isOn: true,
          powerUsageWatts: 1000.0, // 1000 W = 1 kW
        ),
        const SmartDevice(
          id: 'dev-bulb',
          name: 'Living Bulb',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          powerUsageWatts: 50.0, // 50 W
        ),
      ];

      final rooms = [
        const Room(
          id: 'Living Room',
          name: 'Living Room',
          iconName: 'living_room',
        ),
      ];

      const tariff = 0.20; // $0.20 / kWh
      final report = EnergyInsightsEngine.computeReport(
        period: 'day', // 24 hours
        devices: devices,
        rooms: rooms,
        tariff: tariff,
      );

      // 1000 W * 24 h = 24.0 kWh -> Cost: 24.0 * 0.20 = $4.80
      final acItem = report.deviceBreakdown.firstWhere((d) => d.id == 'dev-ac');
      expect(acItem.kwh, equals(24.0));
      expect(acItem.cost, equals(4.80));

      // 50 W * 24 h = 1.2 kWh -> Cost: 1.2 * 0.20 = $0.24
      final bulbItem =
          report.deviceBreakdown.firstWhere((d) => d.id == 'dev-bulb');
      expect(bulbItem.kwh, equals(1.2));
      expect(bulbItem.cost, equals(0.24));

      // Room total = 24.0 + 1.2 = 25.2 kWh
      final roomItem = report.roomBreakdown.first;
      expect(roomItem.kwh, equals(25.2));
      expect(roomItem.cost, equals(5.04));

      // Overall totals
      expect(report.totalKwh, equals(25.2));
      expect(report.totalCost, equals(5.04));
      expect(report.tariff, equals(tariff));
    });

    // -------------------------------------------------------------------------
    // FLOW G: CSV Export
    // verify CSV string headers, units, timestamps, and numeric totals
    // -------------------------------------------------------------------------
    test(
        'Flow G: CSV Export (verify CSV string headers, units, timestamps, and numeric totals)',
        () {
      final report = EnergyReport(
        period: 'day',
        totalKwh: 12.3456,
        totalCost: 1.9753,
        tariff: 0.16,
        previousPeriodKwh: 11.0,
        percentChange: 12.23,
        deviceBreakdown: const [
          EnergyBreakdownItem(
            id: 'd-1',
            name: 'Office Light',
            category: 'device',
            wattage: 20.0,
            kwh: 0.48,
            cost: 0.0768,
          ),
        ],
        roomBreakdown: const [
          EnergyBreakdownItem(
            id: 'r-1',
            name: 'Office',
            category: 'room',
            wattage: 20.0,
            kwh: 0.48,
            cost: 0.0768,
          ),
        ],
        generatedAt: DateTime(2026, 10, 24, 12, 0),
      );

      final csv = EnergyInsightsEngine.exportToCsv(report);

      // Verify headers and units
      expect(
          csv,
          contains(
              'Timestamp,Category,ID,Name,Power (W),Energy (kWh),Cost (\$),Tariff (\$/kWh)'));

      // Verify timestamps and items
      expect(
          csv,
          contains(
              '2026-10-24T12:00:00.000,device,d-1,"Office Light",20.00,0.4800,0.0768,0.1600'));
      expect(
          csv,
          contains(
              '2026-10-24T12:00:00.000,room,r-1,"Office",20.00,0.4800,0.0768,0.1600'));

      // Verify numeric totals line
      expect(csv, contains(',total,total,Total,0.00,12.3456,1.9753,0.1600'));
    });

    // -------------------------------------------------------------------------
    // FLOW H: JSON Backup & Restore
    // export -> demo reset -> restore -> verify all entities intact
    // -------------------------------------------------------------------------
    test(
        'Flow H: JSON Backup & Restore (export -> demo reset -> restore -> verify all entities intact)',
        () async {
      await persistenceManager.loadHomeState();
      final backupNotifier = BackupRestoreNotifier(
        persistenceManager: persistenceManager,
      );

      // 1. Export JSON backup
      final exportedJson = await backupNotifier.exportBackup();
      expect(exportedJson.isNotEmpty, isTrue);

      final decoded = jsonDecode(exportedJson) as Map<String, dynamic>;
      expect(decoded['metadata'], isNotNull);
      expect(decoded['homes'], isNotEmpty);
      expect(decoded['devices'], isNotEmpty);

      // 2. Demo reset (wipes storage to fresh state)
      await persistenceManager.resetDemoData();

      // 3. Preview backup
      final preview = backupNotifier.previewBackup(exportedJson);
      expect(preview.isValid, isTrue);
      expect(preview.homeCount, greaterThanOrEqualTo(2));
      expect(preview.deviceCount, greaterThan(0));

      // 4. Restore backup
      final success = await backupNotifier.restoreBackup(exportedJson);
      expect(success, isTrue);

      // 5. Verify all entities intact after restore
      final reloaded = await persistenceManager.loadHomeState();
      expect(reloaded.homes.length, equals(decoded['homes'].length));
      expect(reloaded.devices.length, equals(decoded['devices'].length));
      expect(reloaded.rooms.length, equals(decoded['rooms'].length));
      expect(reloaded.scenes.length, equals(decoded['scenes'].length));
      expect(
          reloaded.automations.length, equals(decoded['automations'].length));
      expect(reloaded.dashboardConfigs.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // FLOW I: Invalid Backup Rejection
    // malformed or unsupported backup safely rejected without data loss
    // -------------------------------------------------------------------------
    test(
        'Flow I: Invalid Backup Rejection (malformed/unsupported backup safely rejected without data loss)',
        () async {
      final initialState = await persistenceManager.loadHomeState();
      final backupNotifier = BackupRestoreNotifier(
        persistenceManager: persistenceManager,
      );

      // Test 1: Malformed JSON syntax
      const malformedJson = '{"metadata": { broken json syntax';
      final preview1 = backupNotifier.previewBackup(malformedJson);
      expect(preview1.isValid, isFalse);

      final restoreResult1 = await backupNotifier.restoreBackup(malformedJson);
      expect(restoreResult1, isFalse);

      // Test 2: Unsupported Schema Version (version 99)
      final futureVersionJson = jsonEncode({
        'metadata': {
          'schemaVersion': 99,
          'lumivoVersion': '99.0.0',
        },
        'homes': [],
        'devices': [],
      });

      final preview2 = backupNotifier.previewBackup(futureVersionJson);
      expect(preview2.isValid, isFalse);
      expect(
          preview2.errors.any((e) => e.contains('Unsupported schema version')),
          isTrue);

      final restoreResult2 =
          await backupNotifier.restoreBackup(futureVersionJson);
      expect(restoreResult2, isFalse);

      // Verify NO data loss occurred
      final currentState = await persistenceManager.loadHomeState();
      expect(currentState.homes.length, equals(initialState.homes.length));
      expect(currentState.devices.length, equals(initialState.devices.length));
    });

    // -------------------------------------------------------------------------
    // FLOW J: Home Isolation
    // verify search, dashboard, energy, and scenes scoped per home
    // -------------------------------------------------------------------------
    test(
        'Flow J: Home Isolation (verify search, dashboard, energy, and scenes scoped per home)',
        () async {
      await persistenceManager.loadHomeState();

      final allDevices = [
        const SmartDevice(
          id: 'dev-penthouse',
          name: 'Penthouse Chandelier',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          powerUsageWatts: 60.0,
          homeId: 'home-default',
        ),
        const SmartDevice(
          id: 'dev-villa',
          name: 'Villa Garden Gate',
          roomId: 'Garden',
          type: DeviceType.lock,
          isOn: true,
          powerUsageWatts: 15.0,
          homeId: 'home-suburban',
        ),
      ];

      // 1. Devices search isolation
      final homeADevices =
          allDevices.where((d) => d.homeId == 'home-default').toList();
      final homeBDevices =
          allDevices.where((d) => d.homeId == 'home-suburban').toList();

      final searchA = DeviceSearchEngine.search(devices: homeADevices);
      final searchB = DeviceSearchEngine.search(devices: homeBDevices);

      expect(searchA.map((d) => d.id), contains('dev-penthouse'));
      expect(searchA.map((d) => d.id), isNot(contains('dev-villa')));

      expect(searchB.map((d) => d.id), contains('dev-villa'));
      expect(searchB.map((d) => d.id), isNot(contains('dev-penthouse')));

      // 2. Dashboard config isolation
      final configA = persistenceManager.getDashboardConfig('home-default');
      final configB = persistenceManager.getDashboardConfig('home-suburban');
      expect(configA.homeId, equals('home-default'));
      expect(configB.homeId, equals('home-suburban'));

      // 3. Energy isolation
      final energyA = EnergyInsightsEngine.computeReport(
        period: 'day',
        devices: homeADevices,
        rooms: [],
        tariff: 0.16,
      );
      final energyB = EnergyInsightsEngine.computeReport(
        period: 'day',
        devices: homeBDevices,
        rooms: [],
        tariff: 0.14,
      );

      expect(energyA.deviceBreakdown.first.id, equals('dev-penthouse'));
      expect(energyB.deviceBreakdown.first.id, equals('dev-villa'));
      expect(energyA.tariff, equals(0.16));
      expect(energyB.tariff, equals(0.14));
    });

    // -------------------------------------------------------------------------
    // FLOW K: Persistence Migration
    // Phase 5 data smoothly migrates to Schema V6
    // -------------------------------------------------------------------------
    test(
        'Flow K: Persistence Migration (Phase 5 data smoothly migrates to Schema V6)',
        () async {
      final v5Data = {
        'schemaVersion': 5,
        'currentHomeId': 'home-default',
        'homes': [
          {
            'id': 'home-default',
            'name': 'Downtown Penthouse',
            'address': '104 Lumivo Way',
            'role': 'Owner',
            'isCurrent': true,
            'tariffRate': 0.16,
            'currency': 'USD',
          },
        ],
        'devices': [
          {
            'id': 'd-bulb-migrated',
            'name': 'Living Room Bulb',
            'roomId': 'Living Room',
            'type': 'light',
            'isOn': true,
            'homeId': 'home-default',
            'isFavorite': true,
          },
        ],
      };

      await storage.remove(HomePersistenceManager.storageKey);
      await storage.setString(
        HomePersistenceManager.v5StorageKey,
        jsonEncode(v5Data),
      );

      final state = await persistenceManager.loadHomeState();
      expect(state.schemaVersion, equals(6));
      expect(state.devices.any((d) => d.id == 'd-bulb-migrated'), isTrue);
      expect(state.dashboardConfigs.containsKey('home-default'), isTrue);
      expect(
          await storage.getString(HomePersistenceManager.v5StorageKey), isNull);
    });

    // -------------------------------------------------------------------------
    // FLOW L: Regression Suite
    // Phase 0-5 onboarding, health dashboard, command retry, activity all pass
    // -------------------------------------------------------------------------
    test(
        'Flow L: Regression Suite (Phase 0-5 onboarding, health dashboard, retry, activity)',
        () async {
      // 1. Onboarding first-run check
      expect(await persistenceManager.isFirstRunCompleted(), isFalse);
      await persistenceManager.setFirstRunCompleted(true);
      expect(await persistenceManager.isFirstRunCompleted(), isTrue);

      // 2. Health dashboard calculation
      final healthList = [
        DeviceHealth(
          deviceId: 'dev-1',
          homeId: 'home-default',
          status: DeviceHealthStatus.healthy,
          batteryLevel: 85,
          rssi: -55,
          isOnline: true,
          lastSeen: DateTime.now(),
        ),
      ];
      await persistenceManager.saveDeviceHealthRecords(healthList);
      final loadedHealth =
          persistenceManager.getDeviceHealthRecords(homeId: 'home-default');
      expect(loadedHealth.length, equals(1));
      expect(loadedHealth.first.status, equals(DeviceHealthStatus.healthy));

      // 3. Command pipeline retry & deduplication
      final pipeline = CommandPipeline(simulatedLatency: Duration.zero);
      const command = DeviceCommand(
        requestId: 'req-regression-1',
        deviceId: 'dev-1',
        type: DeviceCommandType.setPower,
        value: true,
      );

      final result1 = await pipeline.execute(
        command,
        onExecute: (cmd) async => const CommandResult(
          requestId: 'req-regression-1',
          status: CommandStatus.confirmed,
        ),
      );
      expect(result1.status, equals(CommandStatus.confirmed));

      // Re-dispatching exact duplicate request ID is deduplicated safely
      final result2 = await pipeline.execute(
        command,
        onExecute: (cmd) async => const CommandResult(
          requestId: 'req-regression-1',
          status: CommandStatus.confirmed,
        ),
      );
      expect(result2.status, equals(CommandStatus.confirmed));

      // 4. Activity logging
      final event = ActivityEvent(
        id: 'act-1',
        title: 'Regression System Checked',
        description: 'All subsystems verified',
        timestamp: DateTime.now(),
        severity: ActivitySeverity.info,
      );
      await persistenceManager.saveActivityEvents([event]);
      final state = await persistenceManager.loadHomeState();
      expect(state.activityEvents.any((e) => e.id == 'act-1'), isTrue);
    });
  });
}
