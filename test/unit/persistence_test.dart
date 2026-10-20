import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/in_app_notification.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Persistence and StorageAdapter Tests', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager manager;

    setUp(() {
      storage = StorageAdapterImpl();
      manager = HomePersistenceManager(storage: storage);
    });

    test('StorageAdapter CRUD works correctly', () async {
      expect(await storage.getString('test_key'), isNull);

      await storage.setString('test_key', 'test_val');
      expect(await storage.getString('test_key'), 'test_val');

      await storage.remove('test_key');
      expect(await storage.getString('test_key'), isNull);

      await storage.setString('k1', 'v1');
      await storage.setString('k2', 'v2');
      await storage.clear();
      expect(await storage.getString('k1'), isNull);
      expect(await storage.getString('k2'), isNull);
    });

    test('saveHomeState and loadHomeState serializes/deserializes accurately',
        () async {
      const room = Room(
        id: 'test-room',
        name: 'Test Room',
        iconName: 'home',
        description: 'Test space',
      );
      const device = SmartDevice(
        id: 'dev-1',
        name: 'Test AC',
        roomId: 'test-room',
        type: DeviceType.ac,
        isOn: true,
        targetTemperature: 21.5,
        currentTemperature: 25.0,
      );
      const rule = AutomationRule(
        id: 'rule-1',
        name: 'Test Rule',
        triggerType: TriggerType.schedule,
        timeOfDay: '08:00',
        actions: [
          DeviceAction(
            deviceId: 'dev-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );
      const scene = Scene(
        id: 'scene-1',
        name: 'Chill',
        actions: [],
      );
      final event = ActivityEvent(
        id: 'evt-1',
        title: 'Event 1',
        description: 'Testing event',
        timestamp: DateTime(2026, 10, 20, 10, 0),
        severity: ActivitySeverity.info,
      );
      final notif = InAppNotification(
        id: 'notif-1',
        title: 'Notif 1',
        body: 'Testing notif',
        timestamp: DateTime(2026, 10, 20, 10, 0),
        isRead: false,
      );

      final state = HomeState(
        schemaVersion: 2,
        rooms: [room],
        devices: [device],
        automations: [rule],
        scenes: [scene],
        activityEvents: [event],
        notifications: [notif],
      );

      await manager.saveHomeState(state);

      final loaded = await manager.loadHomeState();
      expect(loaded.schemaVersion, 2);
      expect(loaded.rooms.length, 1);
      expect(loaded.rooms.first.name, 'Test Room');
      expect(loaded.devices.length, 1);
      expect(loaded.devices.first.targetTemperature, 21.5);
      expect(loaded.automations.length, 1);
      expect(loaded.automations.first.name, 'Test Rule');
      expect(loaded.scenes.length, 1);
      expect(loaded.scenes.first.name, 'Chill');
      expect(loaded.activityEvents.length, 1);
      expect(loaded.activityEvents.first.title, 'Event 1');
      expect(loaded.notifications.length, 1);
      expect(loaded.notifications.first.body, 'Testing notif');
    });

    test('Schema version 1 auto-migrates to schema version 2', () async {
      // Legacy Phase 1 payload stored under legacy key
      final phase1Payload = {
        'schemaVersion': 1,
        'devices': [
          {
            'id': 'legacy-light-1',
            'name': 'Legacy Light',
            'roomId': 'Living Room',
            'type': 'light',
            'isOn': true,
            'brightness': 50,
          }
        ],
        // Missing rooms, automations, scenes, notifications
      };

      await storage.setString(
        HomePersistenceManager.legacyStorageKey,
        jsonEncode(phase1Payload),
      );

      final loaded = await manager.loadHomeState();
      expect(loaded.schemaVersion, 2);
      // Maintained existing device
      expect(loaded.devices.any((d) => d.id == 'legacy-light-1'), isTrue);
      // Auto-seeded missing rooms
      expect(loaded.rooms.length, greaterThanOrEqualTo(3));
      // Auto-seeded default scenes & automations
      expect(loaded.scenes.isNotEmpty, isTrue);
      expect(loaded.automations.isNotEmpty, isTrue);
      // Legacy storage key was cleaned up
      expect(
        await storage.getString(HomePersistenceManager.legacyStorageKey),
        isNull,
      );
      // Saved in new storage key
      expect(
        await storage.getString(HomePersistenceManager.storageKey),
        isNotNull,
      );
    });

    test('Corrupted storage data falls back safely to demo data', () async {
      await storage.setString(
        HomePersistenceManager.storageKey,
        '{{INVALID_JSON_CONTENT}}',
      );

      final state = await manager.loadHomeState();
      expect(state.schemaVersion, 2);
      expect(state.devices.length, 7);
      expect(state.rooms.length, greaterThanOrEqualTo(3));
    });

    test(
        'resetDemoData seeds 7 devices, 3+ rooms, default scenes & automations',
        () async {
      final state = await manager.resetDemoData();

      expect(state.schemaVersion, 2);
      // 7 devices: Bulb, Fan, AC, Socket, Curtain, Smart Lock, Sensor
      expect(state.devices.length, 7);
      final types = state.devices.map((d) => d.type).toSet();
      expect(types, contains(DeviceType.light));
      expect(types, contains(DeviceType.fan));
      expect(types, contains(DeviceType.ac));
      expect(types, contains(DeviceType.socket));
      expect(types, contains(DeviceType.curtain));
      expect(types, contains(DeviceType.lock));
      expect(types, contains(DeviceType.sensor));

      // 3+ rooms
      expect(state.rooms.length, greaterThanOrEqualTo(3));
      final roomNames = state.rooms.map((r) => r.name).toSet();
      expect(roomNames, contains('Living Room'));
      expect(roomNames, contains('Bedroom'));
      expect(roomNames, contains('Kitchen'));

      // Default scenes and automations
      expect(state.scenes.length, greaterThanOrEqualTo(3));
      expect(state.automations.length, greaterThanOrEqualTo(3));
    });

    test('Slice update methods preserve other state domains', () async {
      await manager.resetDemoData();

      const newRoom = Room(id: 'Attic', name: 'Attic');
      await manager.saveRooms([newRoom]);

      final state = await manager.loadHomeState();
      expect(state.rooms.length, 1);
      expect(state.rooms.first.name, 'Attic');
      // Devices and scenes remain intact!
      expect(state.devices.length, 7);
      expect(state.scenes.length, greaterThanOrEqualTo(3));
    });
  });
}
