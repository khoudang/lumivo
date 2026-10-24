import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 5 Safe Persistence Schema Migration & QA Test Suite', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager manager;

    setUp(() {
      storage = StorageAdapterImpl();
      manager = HomePersistenceManager(storage: storage);
    });

    // -------------------------------------------------------------
    // 1. Schema Migration: V4 -> V5
    // -------------------------------------------------------------
    test(
        'V4 -> V5 schema migration preserves all Phase 4 devices, rooms, scenes, and settings',
        () async {
      final v4Payload = {
        'schemaVersion': 4,
        'currentHomeId': 'home-suburban',
        'homes': [
          {
            'id': 'home-default',
            'name': 'Downtown Penthouse',
            'address': '104 Lumivo Way',
            'role': 'Owner',
            'isCurrent': false,
            'tariffRate': 0.16,
            'currency': 'USD',
          },
          {
            'id': 'home-suburban',
            'name': 'Suburban Villa',
            'address': '42 Meadow Lane',
            'role': 'Owner',
            'isCurrent': true,
            'tariffRate': 0.14,
            'currency': 'USD',
          },
        ],
        'userProfile': {
          'id': 'user-v4',
          'name': 'Alex Phase4',
          'email': 'alex@lumivo.io',
          'language': 'vi',
          'themeMode': 'oled',
          'accentColor': 4287269887,
          'reducedMotion': true,
          'temperatureUnit': 'C',
        },
        'rooms': [
          {
            'id': 'room-garden',
            'name': 'Zen Garden',
            'iconName': 'yard',
            'description': 'Serene backyard',
            'homeId': 'home-suburban',
          },
        ],
        'devices': [
          {
            'id': 'dev-v4-spotlight',
            'name': 'Landscape Floodlight',
            'roomId': 'room-garden',
            'type': 'light',
            'isOn': true,
            'brightness': 95,
            'isFavorite': true,
            'favoriteOrder': 0,
            'customIcon': 'spotlight',
            'homeId': 'home-suburban',
          },
        ],
        'scenes': [
          {
            'id': 'scene-v4-sunset',
            'name': 'Sunset Glow',
            'iconName': 'flare',
            'homeId': 'home-suburban',
            'actions': [
              {
                'deviceId': 'dev-v4-spotlight',
                'commandType': 'setBrightness',
                'value': 50,
              }
            ],
          }
        ],
        'automations': [
          {
            'id': 'auto-v4-dusk',
            'name': 'Dusk Lighting',
            'isEnabled': true,
            'triggerType': 'schedule',
            'timeOfDay': '19:15',
            'homeId': 'home-suburban',
            'actions': [
              {
                'deviceId': 'dev-v4-spotlight',
                'commandType': 'setPower',
                'value': true,
              }
            ],
          }
        ],
      };

      await storage.setString(
        HomePersistenceManager.v4StorageKey,
        jsonEncode(v4Payload),
      );

      final migrated = await manager.loadHomeState();

      // Verify upgraded to schema version 5+
      expect(migrated.schemaVersion, greaterThanOrEqualTo(5));
      expect(HomePersistenceManager.schemaVersion, greaterThanOrEqualTo(5));

      // Verify current home preserved
      expect(migrated.currentHomeId, 'home-suburban');
      expect(migrated.homes.length, 2);

      // Verify user profile preserved
      expect(migrated.userProfile.name, 'Alex Phase4');
      expect(migrated.userProfile.language, 'vi');
      expect(migrated.userProfile.reducedMotion, isTrue);

      // Verify room & device preserved
      expect(migrated.rooms.any((r) => r.id == 'room-garden'), isTrue);
      final dev =
          migrated.devices.firstWhere((d) => d.id == 'dev-v4-spotlight');
      expect(dev.name, 'Landscape Floodlight');
      expect(dev.brightness, 95);
      expect(dev.isFavorite, isTrue);
      expect(dev.customIcon, 'spotlight');

      // Verify scene & automation preserved
      expect(migrated.scenes.any((s) => s.id == 'scene-v4-sunset'), isTrue);
      expect(migrated.automations.any((a) => a.id == 'auto-v4-dusk'), isTrue);

      // Verify old v4 storage key was cleaned up
      expect(
          await storage.getString(HomePersistenceManager.v4StorageKey), isNull);
      expect(await storage.getString(HomePersistenceManager.storageKey),
          isNotNull);
    });

    // -------------------------------------------------------------
    // 2. Schema Migration: V3 -> V5
    // -------------------------------------------------------------
    test('V3 -> V5 schema migration upgrades safely', () async {
      final v3Payload = {
        'schemaVersion': 3,
        'currentHomeId': 'home-default',
        'rooms': [
          {
            'id': 'Living Room',
            'name': 'Living Room',
            'iconName': 'living_room',
            'homeId': 'home-default',
          }
        ],
        'devices': [
          {
            'id': 'device-bulb-1',
            'name': 'Smart Light',
            'roomId': 'Living Room',
            'type': 'light',
            'isOn': false,
            'homeId': 'home-default',
          }
        ],
      };

      await storage.setString(
        HomePersistenceManager.v3StorageKey,
        jsonEncode(v3Payload),
      );

      final migrated = await manager.loadHomeState();
      expect(migrated.schemaVersion, greaterThanOrEqualTo(5));
      expect(migrated.devices.any((d) => d.id == 'device-bulb-1'), isTrue);
      expect(
          await storage.getString(HomePersistenceManager.v3StorageKey), isNull);
    });

    // -------------------------------------------------------------
    // 3. Robust Corrupted Storage Recovery
    // -------------------------------------------------------------
    test('Corrupted/malformed JSON falls back gracefully to default seed state',
        () async {
      await storage.setString('unrelated_user_key', 'preserve_me');

      // Test 1: Malformed JSON syntax
      await storage.setString(
        HomePersistenceManager.storageKey,
        '{"schemaVersion": 5, "homes": [ {',
      );
      var state = await manager.loadHomeState();
      expect(state.schemaVersion, greaterThanOrEqualTo(5));
      expect(state.homes.length, greaterThanOrEqualTo(2));
      expect(state.devices.isNotEmpty, isTrue);

      // Verify unrelated storage key was NOT wiped
      expect(await storage.getString('unrelated_user_key'), 'preserve_me');

      // Test 2: Arbitrary garbage string
      await storage.setString(
        HomePersistenceManager.storageKey,
        'NOT_EVEN_JSON_CORRUPT_BYTES_XYZ_123',
      );
      state = await manager.loadHomeState();
      expect(state.schemaVersion, greaterThanOrEqualTo(5));
      expect(state.devices.isNotEmpty, isTrue);

      // Test 3: Truncated JSON
      await storage.setString(
        HomePersistenceManager.storageKey,
        '{"schemaVersion": 5, "currentHomeId": "home-def',
      );
      state = await manager.loadHomeState();
      expect(state.schemaVersion, greaterThanOrEqualTo(5));
      expect(state.homes.length, greaterThanOrEqualTo(2));

      // Test 4: Top-level JSON array instead of Map
      await storage.setString(
        HomePersistenceManager.storageKey,
        '[1, 2, 3, "unexpected"]',
      );
      state = await manager.loadHomeState();
      expect(state.schemaVersion, greaterThanOrEqualTo(5));
      expect(state.devices.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // 4. Multi-Home Isolation of Command & Automation Records
    // -------------------------------------------------------------
    test('Command and automation records are isolated per homeId', () async {
      await manager.loadHomeState();

      // Create command records for home-default
      final defaultCommands = List.generate(
        5,
        (i) => CommandRecord(
          requestId: 'cmd-default-$i',
          deviceId: 'device-bulb-1',
          type: DeviceCommandType.setPower,
          value: i.isEven,
          status: CommandStatus.confirmed,
          timestamp: DateTime.now().subtract(Duration(minutes: i)),
          homeId: 'home-default',
        ),
      );

      // Create command records for home-suburban
      final suburbanCommands = List.generate(
        4,
        (i) => CommandRecord(
          requestId: 'cmd-suburban-$i',
          deviceId: 'device-villa-light',
          type: DeviceCommandType.setPower,
          value: true,
          status: CommandStatus.confirmed,
          timestamp: DateTime.now().subtract(Duration(minutes: i)),
          homeId: 'home-suburban',
        ),
      );

      await manager.saveCommandRecords(defaultCommands, homeId: 'home-default');
      await manager.saveCommandRecords(suburbanCommands,
          homeId: 'home-suburban');

      final queriedDefault = manager.getCommandRecords(homeId: 'home-default');
      final queriedSuburban =
          manager.getCommandRecords(homeId: 'home-suburban');

      expect(queriedDefault.length, 5);
      expect(queriedDefault.every((r) => r.homeId == 'home-default'), isTrue);
      expect(queriedDefault.any((r) => r.homeId == 'home-suburban'), isFalse);

      expect(queriedSuburban.length, 4);
      expect(queriedSuburban.every((r) => r.homeId == 'home-suburban'), isTrue);
      expect(queriedSuburban.any((r) => r.homeId == 'home-default'), isFalse);

      // Verify Automation Execution Records isolation
      final defaultAutoRecords = [
        AutomationExecutionRecord(
          id: 'auto-rec-1',
          ruleId: 'rule-temp-trigger',
          ruleName: 'Auto Cool',
          timestamp: DateTime.now(),
          status: AutomationExecutionStatus.executed,
          reason: 'Temperature exceeded threshold',
          homeId: 'home-default',
        ),
      ];
      final suburbanAutoRecords = [
        AutomationExecutionRecord(
          id: 'auto-rec-2',
          ruleId: 'rule-villa-dusk',
          ruleName: 'Villa Dusk',
          timestamp: DateTime.now(),
          status: AutomationExecutionStatus.executed,
          reason: 'Schedule match 18:30',
          homeId: 'home-suburban',
        ),
      ];

      await manager.saveAutomationRecords(defaultAutoRecords,
          homeId: 'home-default');
      await manager.saveAutomationRecords(suburbanAutoRecords,
          homeId: 'home-suburban');

      final defAuto = manager.getAutomationRecords(homeId: 'home-default');
      final subAuto = manager.getAutomationRecords(homeId: 'home-suburban');

      expect(defAuto.length, 1);
      expect(defAuto.first.homeId, 'home-default');
      expect(subAuto.length, 1);
      expect(subAuto.first.homeId, 'home-suburban');
    });

    // -------------------------------------------------------------
    // 5. Bounded History Storage Enforcement (Max 100 Entries)
    // -------------------------------------------------------------
    test(
        'Command & automation histories are strictly bounded to max 100 entries',
        () async {
      await manager.loadHomeState();

      // Attempt to save 135 command records
      final massiveCommandList = List.generate(
        135,
        (i) => CommandRecord(
          requestId: 'massive-cmd-$i',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setPower,
          value: true,
          status: CommandStatus.confirmed,
          timestamp: DateTime.now().subtract(Duration(seconds: 135 - i)),
          homeId: 'home-default',
        ),
      );

      await manager.saveCommandRecords(massiveCommandList,
          homeId: 'home-default');
      final storedCommands = manager.getCommandRecords(homeId: 'home-default');

      expect(storedCommands.length, 100);

      // Reload from raw storage to verify serialization honors bounds
      final reloadedState = await manager.loadHomeState();
      expect(reloadedState.commandRecords.length, lessThanOrEqualTo(100));

      // Attempt to save 120 automation records
      final massiveAutoList = List.generate(
        120,
        (i) => AutomationExecutionRecord(
          id: 'massive-auto-$i',
          ruleId: 'rule-1',
          ruleName: 'Rule $i',
          timestamp: DateTime.now(),
          status: AutomationExecutionStatus.executed,
          reason: 'Batch evaluation',
          homeId: 'home-default',
        ),
      );

      await manager.saveAutomationRecords(massiveAutoList,
          homeId: 'home-default');
      final storedAuto = manager.getAutomationRecords(homeId: 'home-default');

      expect(storedAuto.length, 100);
      final reloadedState2 = await manager.loadHomeState();
      expect(reloadedState2.automationRecords.length, lessThanOrEqualTo(100));
    });

    // -------------------------------------------------------------
    // 6. Security & Sensitive Credential Omission
    // -------------------------------------------------------------
    test('Never persists sensitive Wi-Fi credentials or passwords to storage',
        () async {
      final state = manager.createDemoState();
      final deviceWithSensitiveData = SmartDevice(
        id: 'dev-secure-test',
        name: 'Secure Device',
        roomId: 'Living Room',
        type: DeviceType.socket,
        isOn: true,
        customData: {
          'wifi_password': 'SuperSecretPassword_12345!',
          'password': 'AdminPasswordToStrip',
          'secret_key': '0011223344',
          'normal_metric': 'ok_to_persist',
        },
      );

      final stateWithSensitiveDevice = state.copyWith(
        devices: [...state.devices, deviceWithSensitiveData],
      );

      await manager.saveHomeState(stateWithSensitiveDevice);

      final rawStored =
          await storage.getString(HomePersistenceManager.storageKey);
      expect(rawStored, isNotNull);

      // Sensitive fields must NOT be in the serialized JSON
      expect(rawStored!.contains('SuperSecretPassword_12345!'), isFalse);
      expect(rawStored.contains('AdminPasswordToStrip'), isFalse);
      expect(rawStored.contains('0011223344'), isFalse);
      expect(rawStored.contains('normal_metric'), isTrue);
    });
  });
}
