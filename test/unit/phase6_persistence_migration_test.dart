import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group(
      'Phase 6 Safe Persistence Schema Migration & Multi-Home Isolation Tests',
      () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager manager;

    setUp(() {
      storage = StorageAdapterImpl();
      manager = HomePersistenceManager(storage: storage);
    });

    // -------------------------------------------------------------------------
    // 1. V5 -> V6 Schema Migration
    // -------------------------------------------------------------------------
    test(
        'V5 -> V6 schema migration preserves all Phase 5 state and generates dashboard configs',
        () async {
      final v5Payload = {
        'schemaVersion': 5,
        'currentHomeId': 'home-suburban',
        'homes': [
          {
            'id': 'home-default',
            'name': 'Downtown Loft',
            'address': '101 Urban St',
            'role': 'Owner',
            'isCurrent': false,
            'tariffRate': 0.18,
            'currency': 'USD',
          },
          {
            'id': 'home-suburban',
            'name': 'Suburban Retreat',
            'address': '42 Meadow Lane',
            'role': 'Owner',
            'isCurrent': true,
            'tariffRate': 0.14,
            'currency': 'USD',
          },
        ],
        'userProfile': {
          'id': 'user-alex',
          'name': 'Alex Mercer',
          'email': 'alex@lumivo.io',
          'avatarUrl': '',
          'language': 'vi',
          'themeMode': 'dark',
          'accentColor': 4287331583,
          'reducedMotion': true,
          'temperatureUnit': 'C',
        },
        'rooms': [
          {
            'id': 'room-sunroom',
            'name': 'Sunroom',
            'iconName': 'wb_sunny',
            'description': 'Sun-lit lounge',
            'homeId': 'home-suburban',
          },
        ],
        'devices': [
          {
            'id': 'dev-sun-ac',
            'name': 'Sunroom AC',
            'roomId': 'room-sunroom',
            'type': 'ac',
            'isOn': true,
            'targetTemperature': 21.0,
            'currentTemperature': 23.5,
            'powerUsageWatts': 950.0,
            'homeId': 'home-suburban',
            'isFavorite': true,
            'favoriteOrder': 1,
            'customData': {
              'firmware': 'v1.4.2',
              'wifi_password': 'super_secret_wifi_pass',
              'api_token': 'secret_jwt_token_abc',
            },
          },
        ],
        'scenes': [
          {
            'id': 'scene-relax',
            'name': 'Sunset Relax',
            'iconName': 'bedtime',
            'homeId': 'home-suburban',
            'actions': [
              {
                'deviceId': 'dev-sun-ac',
                'commandType': 'setTargetTemperature',
                'value': 22.0,
              },
            ],
          },
        ],
        'automations': [
          {
            'id': 'rule-sun-cooling',
            'name': 'Auto Sun Cooling',
            'isEnabled': true,
            'triggerType': 'sensorThreshold',
            'sensorDeviceId': 'dev-sun-ac',
            'sensorProperty': 'temperature',
            'operator': 'greaterThan',
            'thresholdValue': 25.0,
            'homeId': 'home-suburban',
            'actions': [
              {
                'deviceId': 'dev-sun-ac',
                'commandType': 'setPower',
                'value': true,
              },
            ],
          },
        ],
        'commandRecords': [
          {
            'requestId': 'cmd-1',
            'deviceId': 'dev-sun-ac',
            'type': 'setPower',
            'value': true,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'confirmed',
            'homeId': 'home-suburban',
          },
        ],
        'automationRecords': [
          {
            'id': 'auto-rec-1',
            'ruleId': 'rule-sun-cooling',
            'ruleName': 'Auto Sun Cooling',
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'executed',
            'reason': 'Temperature 26.0 > 25.0',
            'dispatchedCommandIds': ['cmd-1'],
            'homeId': 'home-suburban',
          },
        ],
      };

      await storage.setString(
        HomePersistenceManager.v5StorageKey,
        jsonEncode(v5Payload),
      );

      final migrated = await manager.loadHomeState();

      // Verify schema version upgraded to 6
      expect(
          migrated.schemaVersion, equals(HomePersistenceManager.schemaVersion));
      expect(HomePersistenceManager.schemaVersion, equals(6));

      // Verify V5 storage key removed and V6 saved
      expect(
          await storage.getString(HomePersistenceManager.v5StorageKey), isNull);
      expect(await storage.getString(HomePersistenceManager.storageKey),
          isNotNull);

      // Verify entities preserved intact
      expect(migrated.currentHomeId, equals('home-suburban'));
      expect(migrated.homes.length, equals(2));
      expect(migrated.userProfile.name, equals('Alex Mercer'));
      expect(migrated.userProfile.language, equals('vi'));
      expect(migrated.rooms.length, equals(1));
      expect(migrated.rooms.first.id, equals('room-sunroom'));

      final dev = migrated.devices.firstWhere((d) => d.id == 'dev-sun-ac');
      expect(dev.isFavorite, isTrue);
      expect(dev.targetTemperature, equals(21.0));
      expect(dev.powerUsageWatts, equals(950.0));

      // Verify sensitive Wi-Fi and token credentials sanitized
      expect(dev.customData.containsKey('firmware'), isTrue);
      expect(dev.customData.containsKey('wifi_password'), isFalse);
      expect(dev.customData.containsKey('api_token'), isFalse);

      // Verify scenes and automations preserved
      expect(migrated.scenes.length, equals(1));
      expect(migrated.scenes.first.id, equals('scene-relax'));
      expect(migrated.automations.length, equals(1));
      expect(migrated.automations.first.id, equals('rule-sun-cooling'));

      // Verify dashboardConfigs generated for all homes
      expect(migrated.dashboardConfigs.containsKey('home-default'), isTrue);
      expect(migrated.dashboardConfigs.containsKey('home-suburban'), isTrue);
      expect(
          migrated.dashboardConfigs['home-suburban']!.sectionOrder, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 2. Multi-Home Dashboard Config Persistence (Home A != Home B)
    // -------------------------------------------------------------------------
    test('Multi-home dashboard configs persist independently per homeId',
        () async {
      await manager.loadHomeState();

      // Home A: Downtown Penthouse layout
      const homeAId = 'home-default';
      final configA = DashboardConfig(
        homeId: homeAId,
        sectionOrder: const [
          DashboardSection.favorites,
          DashboardSection.devices,
          DashboardSection.health,
          DashboardSection.metrics,
        ],
        visibleSections: const {
          DashboardSection.favorites: true,
          DashboardSection.devices: true,
          DashboardSection.health: true,
          DashboardSection.metrics: false,
          DashboardSection.activity: false,
        },
      );

      // Home B: Suburban Villa layout
      const homeBId = 'home-suburban';
      final configB = DashboardConfig(
        homeId: homeBId,
        sectionOrder: const [
          DashboardSection.metrics,
          DashboardSection.quickScenes,
          DashboardSection.activity,
          DashboardSection.devices,
        ],
        visibleSections: const {
          DashboardSection.metrics: true,
          DashboardSection.quickScenes: true,
          DashboardSection.activity: true,
          DashboardSection.devices: true,
          DashboardSection.favorites: false,
        },
      );

      await manager.saveDashboardConfig(configA);
      await manager.saveDashboardConfig(configB);

      // Create new manager instance sharing same storage to verify round-trip persistence
      final newManager = HomePersistenceManager(storage: storage);
      final reloadedState = await newManager.loadHomeState();

      final loadedA = newManager.getDashboardConfig(homeAId);
      final loadedB = newManager.getDashboardConfig(homeBId);

      expect(loadedA.homeId, equals(homeAId));
      expect(loadedB.homeId, equals(homeBId));

      // Home A has favorites first; Home B has metrics first
      expect(loadedA.sectionOrder.first, equals(DashboardSection.favorites));
      expect(loadedB.sectionOrder.first, equals(DashboardSection.metrics));

      // Home A metrics is hidden; Home B metrics is visible
      expect(loadedA.isVisible(DashboardSection.metrics), isFalse);
      expect(loadedB.isVisible(DashboardSection.metrics), isTrue);

      // Home A favorites is visible; Home B favorites is hidden
      expect(loadedA.isVisible(DashboardSection.favorites), isTrue);
      expect(loadedB.isVisible(DashboardSection.favorites), isFalse);

      expect(reloadedState.dashboardConfigs.length, greaterThanOrEqualTo(2));
    });

    // -------------------------------------------------------------------------
    // 3. Robust Corrupted Storage Recovery
    // -------------------------------------------------------------------------
    test(
        'Corrupted or truncated JSON safely recovers fallback default seed state without crashing',
        () async {
      await storage.setString('unrelated_user_pref', 'keep_safe');

      // Test 1: Invalid syntax
      await storage.setString(
        HomePersistenceManager.storageKey,
        '{"schemaVersion": 6, "dashboardConfigs": {BROKEN_JSON',
      );
      var state = await manager.loadHomeState();
      expect(state.schemaVersion, equals(HomePersistenceManager.schemaVersion));
      expect(state.homes.isNotEmpty, isTrue);
      expect(state.dashboardConfigs.isNotEmpty, isTrue);

      // Verify unrelated storage key was NOT touched
      expect(
          await storage.getString('unrelated_user_pref'), equals('keep_safe'));

      // Test 2: Top-level array instead of map
      await storage.setString(
        HomePersistenceManager.storageKey,
        '[{"some": "array"}]',
      );
      state = await manager.loadHomeState();
      expect(state.schemaVersion, equals(HomePersistenceManager.schemaVersion));
      expect(state.devices.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 4. Bounded History Buffers (Max 100 Entries)
    // -------------------------------------------------------------------------
    test(
        'Command & automation execution histories are strictly bounded to 100 entries',
        () async {
      await manager.loadHomeState();

      final manyCommands = List.generate(
        150,
        (i) => CommandRecord(
          requestId: 'cmd-stress-$i',
          deviceId: 'device-bulb-1',
          type: DeviceCommandType.setPower,
          value: i % 2 == 0,
          timestamp: DateTime.now().subtract(Duration(minutes: i)),
          status: CommandStatus.confirmed,
          homeId: 'home-default',
        ),
      );

      final manyAutomations = List.generate(
        140,
        (i) => AutomationExecutionRecord(
          id: 'auto-stress-$i',
          ruleId: 'rule-temp-trigger',
          ruleName: 'Auto Cool Living Room',
          timestamp: DateTime.now().subtract(Duration(minutes: i)),
          status: AutomationExecutionStatus.executed,
          reason: 'Temperature threshold exceeded',
          dispatchedCommandIds: ['cmd-stress-$i'],
          homeId: 'home-default',
        ),
      );

      await manager.saveCommandRecords(manyCommands, homeId: 'home-default');
      await manager.saveAutomationRecords(manyAutomations,
          homeId: 'home-default');

      final freshManager = HomePersistenceManager(storage: storage);
      await freshManager.loadHomeState();

      final savedCommands =
          freshManager.getCommandRecords(homeId: 'home-default');
      final savedAutomations =
          freshManager.getAutomationRecords(homeId: 'home-default');

      expect(savedCommands.length, lessThanOrEqualTo(100));
      expect(savedAutomations.length, lessThanOrEqualTo(100));
    });
  });
}
