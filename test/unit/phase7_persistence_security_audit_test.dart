import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/in_app_notification.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 7 Persistence, Security & Data QA Audit Test Suite', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late BackupRestoreService backupService;

    setUp(() {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);
      backupService = const BackupRestoreService();
    });

    // =========================================================================
    // 1. PERSISTENCE & SCHEMA MIGRATION AUDIT (V1 - V6)
    // =========================================================================
    group('1. Persistence & Migration Audit (V1 - V6)', () {
      test(
          'V1 legacy schema migration: preserves devices and rooms, injects default homes, profile and dashboard configs',
          () async {
        final v1Payload = {
          'devices': [
            {
              'id': 'v1-dev-lamp',
              'name': 'Vintage Lamp',
              'roomId': 'Living Room',
              'type': 'light',
              'isOn': true,
              'brightness': 70,
            },
          ],
          'rooms': [
            {
              'id': 'Living Room',
              'name': 'Living Room',
              'iconName': 'living_room',
            },
          ],
          'scenes': [
            {
              'id': 'v1-scene-1',
              'name': 'Warm Evening',
              'iconName': 'wb_sunny',
              'actions': [
                {
                  'deviceId': 'v1-dev-lamp',
                  'commandType': 'setBrightness',
                  'value': 50,
                },
              ],
            },
          ],
          'automations': [
            {
              'id': 'v1-rule-1',
              'name': 'Auto Evening Lamp',
              'isEnabled': true,
              'triggerType': 'schedule',
              'timeOfDay': '19:00',
              'actions': [
                {
                  'deviceId': 'v1-dev-lamp',
                  'commandType': 'setPower',
                  'value': true,
                },
              ],
            },
          ],
        };

        await storage.setString(
          HomePersistenceManager.legacyStorageKey,
          jsonEncode(v1Payload),
        );

        final state = await persistenceManager.loadHomeState();

        expect(state.schemaVersion, equals(6));
        expect(state.devices.any((d) => d.id == 'v1-dev-lamp'), isTrue);
        final lamp = state.devices.firstWhere((d) => d.id == 'v1-dev-lamp');
        expect(lamp.homeId, equals('home-default'));
        expect(lamp.brightness, equals(70));
        expect(state.homes.length, greaterThanOrEqualTo(2));
        expect(state.currentHomeId, equals('home-default'));
        expect(state.dashboardConfigs.containsKey('home-default'), isTrue);
        expect(await storage.getString(HomePersistenceManager.legacyStorageKey),
            isNull);
      });

      test(
          'V2 -> V6 migration: preserves favorites, order, customIcon and tags homeId',
          () async {
        final v2Payload = {
          'schemaVersion': 2,
          'rooms': [
            {
              'id': 'Studio',
              'name': 'Art Studio',
              'iconName': 'palette',
            },
          ],
          'devices': [
            {
              'id': 'v2-floodlight',
              'name': 'Studio Floodlight',
              'roomId': 'Studio',
              'type': 'light',
              'isOn': false,
              'brightness': 100,
              'isFavorite': true,
              'favoriteOrder': 0,
              'customIcon': 'studio_light',
            },
          ],
        };

        await storage.setString(
          HomePersistenceManager.v2StorageKey,
          jsonEncode(v2Payload),
        );

        final state = await persistenceManager.loadHomeState();

        expect(state.schemaVersion, equals(6));
        final dev = state.devices.firstWhere((d) => d.id == 'v2-floodlight');
        expect(dev.isFavorite, isTrue);
        expect(dev.favoriteOrder, equals(0));
        expect(dev.customIcon, equals('studio_light'));
        expect(dev.homeId, equals('home-default'));
        expect(state.rooms.any((r) => r.id == 'Studio'), isTrue);
        expect(await storage.getString(HomePersistenceManager.v2StorageKey),
            isNull);
      });

      test(
          'V3 -> V6 migration: preserves multi-home definitions, tariff and energy',
          () async {
        final v3Payload = {
          'schemaVersion': 3,
          'currentHomeId': 'home-suburban',
          'homes': [
            {
              'id': 'home-suburban',
              'name': 'Eco Suburban Haven',
              'address': '55 Elm St',
              'role': 'Owner',
              'isCurrent': true,
              'tariffRate': 0.12,
              'currency': 'USD',
            },
          ],
          'devices': [
            {
              'id': 'dev-v3-heater',
              'name': 'Water Heater',
              'roomId': 'Garage',
              'type': 'socket',
              'isOn': true,
              'powerUsageWatts': 1500.0,
              'homeId': 'home-suburban',
            },
          ],
        };

        await storage.setString(
          HomePersistenceManager.v3StorageKey,
          jsonEncode(v3Payload),
        );

        final state = await persistenceManager.loadHomeState();

        expect(state.schemaVersion, equals(6));
        expect(state.currentHomeId, equals('home-suburban'));
        final home = state.homes.firstWhere((h) => h.id == 'home-suburban');
        expect(home.tariffRate, equals(0.12));
        expect(state.dashboardConfigs.containsKey('home-suburban'), isTrue);
      });

      test(
          'V4 -> V6 migration: preserves userProfile settings and localized preferences',
          () async {
        final v4Payload = {
          'schemaVersion': 4,
          'currentHomeId': 'home-default',
          'userProfile': {
            'id': 'usr-phase4',
            'name': 'Nguyen Van A',
            'email': 'vana@lumivo.io',
            'language': 'vi',
            'themeMode': 'dark',
            'accentColor': 4287269887,
            'reducedMotion': true,
            'temperatureUnit': 'C',
          },
          'homes': [
            {
              'id': 'home-default',
              'name': 'Saigon Apartment',
              'address': '104 Le Loi',
              'role': 'Owner',
              'isCurrent': true,
              'tariffRate': 0.15,
              'currency': 'VND',
            },
          ],
          'devices': [],
        };

        await storage.setString(
          HomePersistenceManager.v4StorageKey,
          jsonEncode(v4Payload),
        );

        final state = await persistenceManager.loadHomeState();

        expect(state.schemaVersion, equals(6));
        expect(state.userProfile.name, equals('Nguyen Van A'));
        expect(state.userProfile.language, equals('vi'));
        expect(state.userProfile.reducedMotion, isTrue);
        expect(state.dashboardConfigs.containsKey('home-default'), isTrue);
      });

      test(
          'V5 -> V6 migration: preserves command history, automation history, diagnostics and simulatedModifications',
          () async {
        final v5Payload = {
          'schemaVersion': 5,
          'currentHomeId': 'home-default',
          'homes': [
            {
              'id': 'home-default',
              'name': 'Downtown Loft',
              'address': '101 Urban St',
              'role': 'Owner',
              'isCurrent': true,
              'tariffRate': 0.16,
              'currency': 'USD',
            },
          ],
          'devices': [
            {
              'id': 'dev-v5-lock',
              'name': 'Main Entrance Lock',
              'roomId': 'Living Room',
              'type': 'lock',
              'isOn': true,
              'isLocked': true,
              'homeId': 'home-default',
            },
          ],
          'commandRecords': [
            {
              'requestId': 'req-v5-001',
              'deviceId': 'dev-v5-lock',
              'type': 'setLock',
              'value': true,
              'timestamp': DateTime.now().toIso8601String(),
              'status': 'confirmed',
              'homeId': 'home-default',
            },
          ],
          'automationRecords': [
            {
              'id': 'rec-v5-001',
              'ruleId': 'rule-v5-auto',
              'ruleName': 'Night Lock',
              'timestamp': DateTime.now().toIso8601String(),
              'status': 'executed',
              'reason': 'Scheduled trigger',
              'dispatchedCommandIds': ['req-v5-001'],
              'homeId': 'home-default',
            },
          ],
          'deviceHealthRecords': [
            {
              'deviceId': 'dev-v5-lock',
              'homeId': 'home-default',
              'status': 'healthy',
              'batteryLevel': 92,
              'rssi': -52,
              'isOnline': true,
              'lastSeen': DateTime.now().toIso8601String(),
            },
          ],
          'simulatedModifications': {
            'dev-v5-lock': {'batteryDrainMultiplier': 1.5},
          },
        };

        await storage.setString(
          HomePersistenceManager.v5StorageKey,
          jsonEncode(v5Payload),
        );

        final state = await persistenceManager.loadHomeState();

        expect(state.schemaVersion, equals(6));
        expect(state.commandRecords.length, equals(1));
        expect(state.commandRecords.first.requestId, equals('req-v5-001'));
        expect(state.automationRecords.length, equals(1));
        expect(state.automationRecords.first.id, equals('rec-v5-001'));
        expect(state.deviceHealthRecords.length, equals(1));
        expect(state.deviceHealthRecords.first.batteryLevel, equals(92));
        expect(
            state.simulatedModifications['dev-v5-lock']
                ['batteryDrainMultiplier'],
            equals(1.5));
        expect(state.dashboardConfigs.containsKey('home-default'), isTrue);
      });

      test(
          'V6 roundtrip persistence: preserves all entities and dashboardConfigs cleanly',
          () async {
        final demo = persistenceManager.createDemoState();
        final customizedConfig = DashboardConfig(
          homeId: 'home-default',
          sectionOrder: const [
            DashboardSection.favorites,
            DashboardSection.devices,
            DashboardSection.metrics,
          ],
          visibleSections: const {
            DashboardSection.favorites: true,
            DashboardSection.devices: true,
            DashboardSection.metrics: false,
          },
        );
        final stateToSave = demo.copyWith(
          dashboardConfigs: {
            'home-default': customizedConfig,
          },
        );

        await persistenceManager.saveHomeState(stateToSave);

        final freshManager = HomePersistenceManager(storage: storage);
        final loaded = await freshManager.loadHomeState();

        expect(loaded.schemaVersion, equals(6));
        final cfg = loaded.dashboardConfigs['home-default'];
        expect(cfg, isNotNull);
        expect(cfg!.sectionOrder.first, equals(DashboardSection.favorites));
        expect(cfg.isVisible(DashboardSection.metrics), isFalse);
      });

      test(
          'Corrupted, malformed, or truncated JSON safely recovers fallback default state without crashing',
          () async {
        await storage.setString('unrelated_secure_token', 'preserve_me');

        // Case 1: Corrupted syntax
        await storage.setString(
          HomePersistenceManager.storageKey,
          '{"schemaVersion": 6, "devices": [ TRUNCATED_OR_BROKEN_SYNTAX',
        );
        final state1 = await persistenceManager.loadHomeState();
        expect(state1.schemaVersion, equals(6));
        expect(state1.devices.isNotEmpty, isTrue);
        expect(await storage.getString('unrelated_secure_token'),
            equals('preserve_me'));

        // Case 2: Negative schema version
        await storage.setString(
          HomePersistenceManager.storageKey,
          jsonEncode({'schemaVersion': -1, 'devices': []}),
        );
        final state2 = await persistenceManager.loadHomeState();
        expect(state2.schemaVersion, equals(6));
        expect(state2.homes.isNotEmpty, isTrue);

        // Case 3: Unsupported future schema version (> 6)
        await storage.setString(
          HomePersistenceManager.storageKey,
          jsonEncode({'schemaVersion': 99, 'devices': []}),
        );
        final state3 = await persistenceManager.loadHomeState();
        expect(state3.schemaVersion, equals(6));
        expect(state3.homes.isNotEmpty, isTrue);
      });

      test(
          'History collections (commands, automations, notifications, activity) are strictly bounded to 100 entries',
          () async {
        await persistenceManager.loadHomeState();

        // 150 commands
        final commands = List.generate(
          150,
          (i) => CommandRecord(
            requestId: 'cmd-b-$i',
            deviceId: 'dev-1',
            type: DeviceCommandType.setPower,
            value: true,
            timestamp: DateTime.now().subtract(Duration(seconds: i)),
            status: CommandStatus.confirmed,
            homeId: 'home-default',
          ),
        );
        await persistenceManager.saveCommandRecords(commands);

        // 140 automation records
        final autoRecords = List.generate(
          140,
          (i) => AutomationExecutionRecord(
            id: 'auto-b-$i',
            ruleId: 'rule-1',
            ruleName: 'Test Rule',
            timestamp: DateTime.now().subtract(Duration(seconds: i)),
            status: AutomationExecutionStatus.executed,
            reason: 'Threshold met',
            dispatchedCommandIds: ['cmd-b-$i'],
            homeId: 'home-default',
          ),
        );
        await persistenceManager.saveAutomationRecords(autoRecords);

        // 130 activity events
        final events = List.generate(
          130,
          (i) => ActivityEvent(
            id: 'act-b-$i',
            title: 'Activity $i',
            description: 'Description $i',
            timestamp: DateTime.now().subtract(Duration(seconds: i)),
            homeId: 'home-default',
          ),
        );
        await persistenceManager.saveActivityEvents(events);

        // 120 notifications
        final notifs = List.generate(
          120,
          (i) => InAppNotification(
            id: 'notif-b-$i',
            title: 'Notification $i',
            body: 'Body $i',
            timestamp: DateTime.now().subtract(Duration(seconds: i)),
            homeId: 'home-default',
          ),
        );
        await persistenceManager.saveNotifications(notifs);

        // Reload fresh from storage to verify persistent bounding
        final freshManager = HomePersistenceManager(storage: storage);
        final loaded = await freshManager.loadHomeState();

        expect(loaded.commandRecords.length, lessThanOrEqualTo(100));
        expect(loaded.automationRecords.length, lessThanOrEqualTo(100));
        expect(loaded.activityEvents.length, lessThanOrEqualTo(100));
        expect(loaded.notifications.length, lessThanOrEqualTo(100));

        // Test JSON serialization bounding
        final json = loaded.toJson();
        expect((json['commandRecords'] as List).length, lessThanOrEqualTo(100));
        expect(
            (json['automationRecords'] as List).length, lessThanOrEqualTo(100));
        expect((json['activityEvents'] as List).length, lessThanOrEqualTo(100));
        expect((json['notifications'] as List).length, lessThanOrEqualTo(100));
      });
    });

    // =========================================================================
    // 2. MULTI-HOME DATA ISOLATION & CASCADING DELETION AUDIT
    // =========================================================================
    group('2. Multi-Home Data Isolation & Cascading Deletion Audit', () {
      test('Home A entities are strictly isolated from Home B', () async {
        final state = await persistenceManager.loadHomeState();

        final homeADevices =
            state.devices.where((d) => d.homeId == 'home-default').toList();
        final homeBDevices =
            state.devices.where((d) => d.homeId == 'home-suburban').toList();

        expect(homeADevices.isNotEmpty, isTrue);
        expect(homeBDevices.isNotEmpty, isTrue);

        // Verify zero overlap in IDs
        final setA = homeADevices.map((d) => d.id).toSet();
        final setB = homeBDevices.map((d) => d.id).toSet();
        expect(setA.intersection(setB), isEmpty);

        // Verify rooms isolation
        final roomsA =
            state.rooms.where((r) => r.homeId == 'home-default').toList();
        final roomsB =
            state.rooms.where((r) => r.homeId == 'home-suburban').toList();
        expect(roomsA.any((r) => r.name == 'Garden'), isFalse);
        expect(roomsB.any((r) => r.name == 'Garden'), isTrue);

        // Verify scenes isolation
        final scenesA =
            state.scenes.where((s) => s.homeId == 'home-default').toList();
        final scenesB =
            state.scenes.where((s) => s.homeId == 'home-suburban').toList();
        expect(scenesA.any((s) => s.name == 'Villa Evening'), isFalse);
        expect(scenesB.any((s) => s.name == 'Villa Evening'), isTrue);

        // Verify automations isolation
        final rulesA =
            state.automations.where((a) => a.homeId == 'home-default').toList();
        final rulesB = state.automations
            .where((a) => a.homeId == 'home-suburban')
            .toList();
        expect(rulesA.any((r) => r.id == 'rule-villa-dusk'), isFalse);
        expect(rulesB.any((r) => r.id == 'rule-villa-dusk'), isTrue);
      });

      test(
          'deleteDeviceWithCascade removes device, prunes favorites, scenes, automations and logs cascade event',
          () async {
        await persistenceManager.loadHomeState();

        // Target device: device-ac-1 (referenced in scene-1, scene-3, rule-temp-trigger)
        const targetDeviceId = 'device-ac-1';

        await persistenceManager.deleteDeviceWithCascade(targetDeviceId);

        final updatedState = await persistenceManager.loadHomeState();

        // 1. Device removed from devices
        expect(
            updatedState.devices.any((d) => d.id == targetDeviceId), isFalse);

        // 2. Favorites re-indexed
        final favs = updatedState.devices.where((d) => d.isFavorite).toList()
          ..sort((a, b) => a.favoriteOrder.compareTo(b.favoriteOrder));
        expect(favs.any((d) => d.id == targetDeviceId), isFalse);
        for (int i = 0; i < favs.length; i++) {
          expect(favs[i].favoriteOrder, equals(i));
        }

        // 3. Pruned from scenes
        for (final scene in updatedState.scenes) {
          expect(
            scene.actions.any((a) => a.deviceId == targetDeviceId),
            isFalse,
          );
        }

        // 4. Pruned or disabled in automations
        for (final rule in updatedState.automations) {
          expect(
            rule.actions.any((a) => a.deviceId == targetDeviceId),
            isFalse,
          );
          if (rule.sensorDeviceId == targetDeviceId) {
            expect(rule.isEnabled, isFalse);
          }
        }

        // 5. Activity event recorded
        expect(
          updatedState.activityEvents.any(
            (e) =>
                e.title.contains('Cascade Deletion') &&
                e.deviceId == targetDeviceId,
          ),
          isTrue,
        );
      });

      test(
          'deleteRoomWithCascade safely reassigns associated devices and updates persistence',
          () async {
        await persistenceManager.loadHomeState();

        // Target room: 'Bedroom' (contains device-ac-1, device-sensor-1)
        const targetRoom = 'Bedroom';
        const fallbackRoom = 'Living Room';

        await persistenceManager.deleteRoomWithCascade(
          targetRoom,
          reassignToRoomId: fallbackRoom,
        );

        final updatedState = await persistenceManager.loadHomeState();

        // Room removed
        expect(updatedState.rooms.any((r) => r.id == targetRoom), isFalse);

        // Devices previously in Bedroom now safely in Living Room
        final ac =
            updatedState.devices.firstWhere((d) => d.id == 'device-ac-1');
        final sensor =
            updatedState.devices.firstWhere((d) => d.id == 'device-sensor-1');
        expect(ac.roomId, equals(fallbackRoom));
        expect(sensor.roomId, equals(fallbackRoom));

        // Activity event logged
        expect(
          updatedState.activityEvents
              .any((e) => e.title.contains('Room Deleted: Bedroom')),
          isTrue,
        );
      });

      test(
          'deleteHomeWithCascade purges all home-scoped data and switches current home safely',
          () async {
        await persistenceManager.loadHomeState();

        const homeToDelete = 'home-suburban';

        await persistenceManager.deleteHomeWithCascade(homeToDelete);

        final updatedState = await persistenceManager.loadHomeState();

        // Home deleted
        expect(updatedState.homes.any((h) => h.id == homeToDelete), isFalse);

        // All home-scoped entities purged
        expect(
            updatedState.devices.any((d) => d.homeId == homeToDelete), isFalse);
        expect(
            updatedState.rooms.any((r) => r.homeId == homeToDelete), isFalse);
        expect(
            updatedState.scenes.any((s) => s.homeId == homeToDelete), isFalse);
        expect(updatedState.automations.any((a) => a.homeId == homeToDelete),
            isFalse);
        expect(
            updatedState.dashboardConfigs.containsKey(homeToDelete), isFalse);

        // Current home fallback remains valid
        expect(updatedState.currentHomeId, equals('home-default'));
      });
    });

    // =========================================================================
    // 3. SECURITY & SANITIZATION AUDIT
    // =========================================================================
    group('3. Security & Sanitization Audit', () {
      test(
          'SmartDevice.toJson() strictly strips passwords, secrets, and auth tokens',
          () {
        const device = SmartDevice(
          id: 'dev-sec-1',
          name: 'Secure Camera',
          roomId: 'Living Room',
          type: DeviceType.security,
          isOn: true,
          customData: {
            'firmware': 'v3.2.0',
            'ip_address': '192.168.1.105',
            'wifi_password': 'SuperSecretWifiPassword!2026',
            'api_token': 'bearer_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
            'private_key': '-----BEGIN PRIVATE KEY-----',
            'credential_secret': 'abc123secret',
            'auth_code': 'auth-xyz',
          },
        );

        final json = device.toJson();
        final custom = json['customData'] as Map<String, dynamic>;

        // Non-sensitive preserved
        expect(custom['firmware'], equals('v3.2.0'));
        expect(custom['ip_address'], equals('192.168.1.105'));

        // Sensitive credentials strictly absent
        expect(custom.containsKey('wifi_password'), isFalse);
        expect(custom.containsKey('api_token'), isFalse);
        expect(custom.containsKey('private_key'), isFalse);
        expect(custom.containsKey('credential_secret'), isFalse);
        expect(custom.containsKey('auth_code'), isFalse);
      });

      test('exportBackupJson produces fully sanitized JSON with no credentials',
          () async {
        final state = await persistenceManager.loadHomeState();
        final devWithSecrets = state.devices.first.copyWith(
          customData: {
            'model': 'LM-500',
            'wifi_pass': 'wifi1234',
            'secret': 'very_secret',
            'token': 'jwt_999',
          },
        );
        await persistenceManager
            .saveDevices([devWithSecrets, ...state.devices.skip(1)]);

        final jsonString = await backupService.exportBackupJson(
            persistenceManager: persistenceManager);

        expect(jsonString.contains('wifi_pass'), isFalse);
        expect(jsonString.contains('very_secret'), isFalse);
        expect(jsonString.contains('jwt_999'), isFalse);
        expect(jsonString.contains('LM-500'), isTrue);
      });

      test('Oversized backup payloads (> 5MB) are strictly rejected', () async {
        // Construct payload > 5MB
        final hugePadding = 'A' * (5 * 1024 * 1024 + 1024);
        final hugeJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'homes': [],
          'devices': [],
          'padding': hugePadding,
        });

        final preview = await backupService.validateAndPreviewBackup(hugeJson);
        expect(preview.isValid, isFalse);
        expect(
          preview.errors.any((e) => e.contains('5MB')),
          isTrue,
        );

        final restoreSuccess = await backupService.restoreBackup(
          jsonString: hugeJson,
          persistenceManager: persistenceManager,
        );
        expect(restoreSuccess, isFalse);
      });

      test('Negative or unsupported schema versions (> 6) are rejected',
          () async {
        // Negative version
        final negJson = jsonEncode({
          'metadata': {'schemaVersion': -1},
          'homes': [],
          'devices': [],
        });
        final negPreview =
            await backupService.validateAndPreviewBackup(negJson);
        expect(negPreview.isValid, isFalse);

        // Version 0
        final zeroJson = jsonEncode({
          'metadata': {'schemaVersion': 0},
          'homes': [],
          'devices': [],
        });
        final zeroPreview =
            await backupService.validateAndPreviewBackup(zeroJson);
        expect(zeroPreview.isValid, isFalse);

        // Version 7 (unsupported future)
        final futureJson = jsonEncode({
          'metadata': {'schemaVersion': 7},
          'homes': [],
          'devices': [],
        });
        final futurePreview =
            await backupService.validateAndPreviewBackup(futureJson);
        expect(futurePreview.isValid, isFalse);
        expect(
          futurePreview.errors
              .any((e) => e.contains('Unsupported schema version')),
          isTrue,
        );
      });

      test('Duplicate IDs in payload are rejected during backup validation',
          () async {
        final duplicateDevicesJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'homes': [
            {'id': 'home-1', 'name': 'Home 1'},
          ],
          'rooms': [
            {'id': 'room-1', 'name': 'Room 1'},
          ],
          'devices': [
            {'id': 'dup-dev', 'name': 'Bulb 1', 'roomId': 'room-1'},
            {'id': 'dup-dev', 'name': 'Bulb 2', 'roomId': 'room-1'},
          ],
          'scenes': [],
          'automations': [],
        });

        final preview =
            await backupService.validateAndPreviewBackup(duplicateDevicesJson);
        expect(preview.isValid, isFalse);
        expect(
          preview.errors
              .any((e) => e.contains('Duplicate device ID found: dup-dev')),
          isTrue,
        );
      });

      test(
          'Transactional rollback: failed restore rolls back to pre-restore state with zero data corruption',
          () async {
        final preState = await persistenceManager.loadHomeState();
        final preHomesCount = preState.homes.length;
        final preDevicesCount = preState.devices.length;

        // Malformed payload that fails pre-validation
        const invalidPayload = '{"metadata": { INVALID_JSON';

        final success = await backupService.restoreBackup(
          jsonString: invalidPayload,
          persistenceManager: persistenceManager,
        );

        expect(success, isFalse);

        // State remains completely identical
        final postState = await persistenceManager.loadHomeState();
        expect(postState.homes.length, equals(preHomesCount));
        expect(postState.devices.length, equals(preDevicesCount));
        expect(postState.currentHomeId, equals(preState.currentHomeId));
      });
    });
  });
}
