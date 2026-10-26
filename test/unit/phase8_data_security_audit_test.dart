import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/discovered_device.dart';
import 'package:lumivo/core/models/energy_report.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/energy/state/energy_insights_notifier.dart';
import 'package:lumivo/features/onboarding/state/onboarding_notifier.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/backup/backup_validation_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/provisioning/mock_provisioning_service.dart';
import 'package:lumivo/services/security/secret_sanitizer.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

/// Fault-injecting storage adapter to simulate QuotaExceededError and write failures.
class FaultInjectingStorageAdapter implements StorageAdapter {
  FaultInjectingStorageAdapter({this.failOnKey});

  final Map<String, String> _store = {};
  String? failOnKey;
  bool shouldThrowQuotaError = false;
  int setStringCallCount = 0;

  @override
  Future<String?> getString(String key) async => _store[key];

  @override
  Future<bool> setString(String key, String value) async {
    setStringCallCount++;
    if (failOnKey != null && key == failOnKey) {
      throw StateError('Simulated write failure on key: $key');
    }
    if (shouldThrowQuotaError && key == HomePersistenceManager.storageKey) {
      // Throw once then allow subsequent retry after pruning
      shouldThrowQuotaError = false;
      throw Exception('QuotaExceededError: DOM storage limit exceeded');
    }
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _store.clear;
    return true;
  }
}

void main() {
  group(
      'Phase 8 — Data Security, Strict Validation & Storage Resilience Audit Suite',
      () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late BackupRestoreService backupService;
    late BackupValidationService validationService;
    late EnergyInsightsService energyService;

    setUp(() {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);
      backupService = const BackupRestoreService();
      validationService = const BackupValidationService();
      energyService = const EnergyInsightsService();
      BackupRestoreService.resetConcurrencyLock();
    });

    // =========================================================================
    // SECTION 1: FEATURE A — STRICT BACKUP VALIDATION SERVICE
    // =========================================================================
    group('1. Feature A — Strict Backup Validation Service', () {
      test('1.1 Supported schema version checking (1 to 6)', () {
        // Valid schema versions 1 through 6
        for (int v = 1; v <= 6; v++) {
          final payload = jsonEncode({
            'metadata': {'schemaVersion': v},
            'homes': [
              {'id': 'home-1', 'name': 'Main House'}
            ],
            'rooms': [
              {'id': 'room-1', 'name': 'Living Room'}
            ],
            'devices': [
              {'id': 'dev-1', 'name': 'Ceiling Light', 'roomId': 'room-1'}
            ],
          });
          final result = BackupValidationService.validate(payload);
          expect(result.isValid, isTrue, reason: 'Version $v should be valid');
        }

        // Negative schema version
        final negJson = jsonEncode({'schemaVersion': -1});
        final negResult = BackupValidationService.validate(negJson);
        expect(negResult.isValid, isFalse);
        expect(
          negResult.errors.any((e) => e.contains('Unsupported schema version')),
          isTrue,
        );

        // Schema version 0
        final zeroJson = jsonEncode({'schemaVersion': 0});
        final zeroResult = BackupValidationService.validate(zeroJson);
        expect(zeroResult.isValid, isFalse);

        // Unsupported future schema version (> 6)
        final futureJson = jsonEncode({
          'metadata': {'schemaVersion': 7},
        });
        final futureResult = BackupValidationService.validate(futureJson);
        expect(futureResult.isValid, isFalse);
        expect(
          futureResult.errors
              .any((e) => e.contains('Unsupported schema version')),
          isTrue,
        );

        // Missing schemaVersion
        final missingVerJson = jsonEncode({
          'homes': [
            {'id': 'home-1', 'name': 'Home 1'}
          ],
        });
        final missingResult = BackupValidationService.validate(missingVerJson);
        expect(missingResult.isValid, isFalse);
        expect(
          missingResult.errors.any((e) => e.contains('Missing schemaVersion')),
          isTrue,
        );
      });

      test('1.2 Payload size limit rejects payloads exceeding 5MB', () {
        final hugePadding = 'X' * (5 * 1024 * 1024 + 100);
        final hugeJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'homes': [],
          'padding': hugePadding,
        });

        final result = BackupValidationService.validate(hugeJson);
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('5MB')), isTrue);
      });

      test('1.3 Nesting depth limit strictly rejects depth > 10', () {
        // Construct nesting depth 11: 11 nested maps
        dynamic nested = {'value': 'deep-leaf'};
        for (int i = 0; i < 11; i++) {
          nested = {'layer_$i': nested};
        }
        final deepJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'deepObject': nested,
        });

        final result = BackupValidationService.validate(deepJson);
        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.contains('nesting depth')),
          isTrue,
        );

        // Valid shallow nesting (depth <= 10)
        final shallowJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'homes': [
            {
              'id': 'home-1',
              'name': 'Home 1',
              'config': {
                'sub': {'setting': true}
              }
            }
          ],
        });
        final shallowResult = BackupValidationService.validate(shallowJson);
        expect(
          shallowResult.errors.any((e) => e.contains('nesting depth')),
          isFalse,
        );
      });

      test(
          '1.4 Entity count limits (max 500 devices, 100 rooms, 200 scenes, 200 automations, 500 events)',
          () {
        // Exceeding devices limit (> 500)
        final excessDevices = List.generate(
          501,
          (i) => {
            'id': 'dev-$i',
            'name': 'Device $i',
            'roomId': 'room-1',
          },
        );
        final excessDevicesJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'room-1', 'name': 'Room 1'}
          ],
          'devices': excessDevices,
        });
        final devResult = BackupValidationService.validate(excessDevicesJson);
        expect(devResult.isValid, isFalse);
        expect(
          devResult.errors
              .any((e) => e.contains('Device count exceeds limit of 500')),
          isTrue,
        );

        // Exceeding rooms limit (> 100)
        final excessRooms = List.generate(
          101,
          (i) => {'id': 'room-$i', 'name': 'Room $i'},
        );
        final roomResult = BackupValidationService.validate(jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': excessRooms,
        }));
        expect(roomResult.isValid, isFalse);
        expect(
          roomResult.errors
              .any((e) => e.contains('Room count exceeds limit of 100')),
          isTrue,
        );

        // Exceeding scenes limit (> 200)
        final excessScenes = List.generate(
          201,
          (i) => {'id': 'scene-$i', 'name': 'Scene $i'},
        );
        final sceneResult = BackupValidationService.validate(jsonEncode({
          'metadata': {'schemaVersion': 6},
          'scenes': excessScenes,
        }));
        expect(sceneResult.isValid, isFalse);
        expect(
          sceneResult.errors
              .any((e) => e.contains('Scene count exceeds limit of 200')),
          isTrue,
        );

        // Exceeding automations limit (> 200)
        final excessAutomations = List.generate(
          201,
          (i) => {'id': 'auto-$i', 'name': 'Rule $i'},
        );
        final autoResult = BackupValidationService.validate(jsonEncode({
          'metadata': {'schemaVersion': 6},
          'automations': excessAutomations,
        }));
        expect(autoResult.isValid, isFalse);
        expect(
          autoResult.errors
              .any((e) => e.contains('Automation count exceeds limit of 200')),
          isTrue,
        );

        // Exceeding events limit (> 500)
        final excessEvents = List.generate(
          501,
          (i) => {'id': 'evt-$i', 'title': 'Event $i'},
        );
        final evtResult = BackupValidationService.validate(jsonEncode({
          'metadata': {'schemaVersion': 6},
          'activityEvents': excessEvents,
        }));
        expect(evtResult.isValid, isFalse);
        expect(
          evtResult.errors
              .any((e) => e.contains('Event count exceeds limit of 500')),
          isTrue,
        );
      });

      test('1.5 Field validation & unique entity IDs across collections', () {
        // Missing required field (roomId on device)
        final missingRoomIdJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'devices': [
            {'id': 'dev-1', 'name': 'Lamp Without Room'}
          ],
        });
        final missingRoomResult =
            BackupValidationService.validate(missingRoomIdJson);
        expect(missingRoomResult.isValid, isFalse);
        expect(
          missingRoomResult.errors
              .any((e) => e.contains('missing required "roomId"')),
          isTrue,
        );

        // Duplicate room IDs
        final dupRoomsJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'room-dup', 'name': 'Living Room'},
            {'id': 'room-dup', 'name': 'Kitchen'},
          ],
        });
        final dupRoomResult = BackupValidationService.validate(dupRoomsJson);
        expect(dupRoomResult.isValid, isFalse);
        expect(
          dupRoomResult.errors
              .any((e) => e.contains('Duplicate room ID found: room-dup')),
          isTrue,
        );

        // Duplicate scene IDs
        final dupScenesJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'scenes': [
            {'id': 'scene-dup', 'name': 'Morning'},
            {'id': 'scene-dup', 'name': 'Evening'},
          ],
        });
        final dupSceneResult = BackupValidationService.validate(dupScenesJson);
        expect(dupSceneResult.isValid, isFalse);
        expect(
          dupSceneResult.errors
              .any((e) => e.contains('Duplicate scene ID found: scene-dup')),
          isTrue,
        );
      });

      test('1.6 Referential integrity: devices, rooms, scenes, and automations',
          () {
        // Device referencing non-existent room
        final invalidRoomRefJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'room-living', 'name': 'Living Room'}
          ],
          'devices': [
            {'id': 'dev-1', 'name': 'Bulb', 'roomId': 'room-non-existent'}
          ],
        });
        final roomRefResult =
            BackupValidationService.validate(invalidRoomRefJson);
        expect(roomRefResult.isValid, isFalse);
        expect(
          roomRefResult.errors.any((e) =>
              e.contains('references non-existent room: room-non-existent')),
          isTrue,
        );

        // Device referencing non-existent home
        final invalidHomeRefJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'homes': [
            {'id': 'home-alpha', 'name': 'Alpha Home'}
          ],
          'rooms': [
            {'id': 'room-living', 'name': 'Living Room'}
          ],
          'devices': [
            {
              'id': 'dev-1',
              'name': 'Bulb',
              'roomId': 'room-living',
              'homeId': 'home-ghost',
            }
          ],
        });
        final homeRefResult =
            BackupValidationService.validate(invalidHomeRefJson);
        expect(homeRefResult.isValid, isFalse);
        expect(
          homeRefResult.errors.any(
              (e) => e.contains('references non-existent home: home-ghost')),
          isTrue,
        );

        // Automation sensor referencing non-existent device
        final invalidSensorRefJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'r1', 'name': 'Room 1'}
          ],
          'devices': [
            {'id': 'd1', 'name': 'D1', 'roomId': 'r1'}
          ],
          'automations': [
            {
              'id': 'rule-1',
              'name': 'Auto Temp',
              'sensorDeviceId': 'device-sensor-missing',
              'actions': [],
            }
          ],
        });
        final sensorRefResult =
            BackupValidationService.validate(invalidSensorRefJson);
        expect(sensorRefResult.isValid, isFalse);
        expect(
          sensorRefResult.errors.any((e) => e.contains(
              'sensor references non-existent device: device-sensor-missing')),
          isTrue,
        );
      });

      test('1.7 Numeric bounds and ISO-8601 timestamp validation', () {
        // Out of bounds power wattage (> 10000)
        final badWattsJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'r1', 'name': 'Room 1'}
          ],
          'devices': [
            {
              'id': 'dev-overload',
              'name': 'Super Heater',
              'roomId': 'r1',
              'powerUsageWatts': 15000.0,
            }
          ],
        });
        final wattsResult = BackupValidationService.validate(badWattsJson);
        expect(wattsResult.isValid, isFalse);
        expect(
          wattsResult.errors.any(
              (e) => e.contains('powerUsageWatts (15000.0) out of bounds')),
          isTrue,
        );

        // Out of bounds brightness (< 0)
        final badBrightnessJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'r1', 'name': 'Room 1'}
          ],
          'devices': [
            {
              'id': 'dev-dim',
              'name': 'Dimmer',
              'roomId': 'r1',
              'brightness': -25,
            }
          ],
        });
        final brightnessResult =
            BackupValidationService.validate(badBrightnessJson);
        expect(brightnessResult.isValid, isFalse);
        expect(
          brightnessResult.errors
              .any((e) => e.contains('brightness (-25) out of bounds')),
          isTrue,
        );

        // Out of bounds target temperature (> 40 C)
        final badTempJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'r1', 'name': 'Room 1'}
          ],
          'devices': [
            {
              'id': 'dev-ac',
              'name': 'AC',
              'roomId': 'r1',
              'targetTemperature': 48.0,
            }
          ],
        });
        final tempResult = BackupValidationService.validate(badTempJson);
        expect(tempResult.isValid, isFalse);
        expect(
          tempResult.errors
              .any((e) => e.contains('targetTemperature (48.0) out of bounds')),
          isTrue,
        );

        // String length > 128 chars
        final longName = 'A' * 135;
        final badStringJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'rooms': [
            {'id': 'r1', 'name': longName}
          ],
        });
        final stringResult = BackupValidationService.validate(badStringJson);
        expect(stringResult.isValid, isFalse);
        expect(
          stringResult.errors.any((e) =>
              e.contains('exceeds maximum allowed length of 128 characters')),
          isTrue,
        );

        // Invalid ISO-8601 timestamp
        final badTimestampJson = jsonEncode({
          'metadata': {
            'schemaVersion': 6,
            'exportedAt': 'NOT_A_VALID_DATE_STRING',
          },
          'homes': [],
        });
        final tsResult = BackupValidationService.validate(badTimestampJson);
        expect(tsResult.isValid, isFalse);
        expect(
          tsResult.errors.any((e) => e.contains('Invalid ISO-8601 timestamp')),
          isTrue,
        );
      });

      test(
          '1.8 Structured BackupValidationResult without throwing uncaught exceptions',
          () {
        // Completely broken syntax
        final res1 =
            BackupValidationService.validate('{ broken json syntax !!!');
        expect(res1.isValid, isFalse);
        expect(res1.errors.isNotEmpty, isTrue);
        expect(res1.previewSummary, isNotNull);

        // Empty string
        final res2 = BackupValidationService.validate('   ');
        expect(res2.isValid, isFalse);
        expect(res2.errors.first, equals('Payload is empty.'));

        // Non-object root
        final res3 = validationService.validateSync('[1, 2, 3]');
        expect(res3.isValid, isFalse);
        expect(
            res3.errors.first, equals('Root payload must be a JSON object.'));
      });
    });

    // =========================================================================
    // SECTION 2: FEATURE B — PRIVACY & SECRET SANITIZATION
    // =========================================================================
    group('2. Feature B — Privacy & Secret Sanitization', () {
      test(
          '2.1 Deep sanitization removes sensitive keywords from nested customData maps and lists',
          () {
        final rawData = {
          'deviceModel': 'LM-Pro-2026',
          'network': {
            'wifiPassword': 'SuperSecretWifiPassword123!',
            'ssid': 'HomeOffice_5G',
            'security': {
              'apiKey': 'ak_live_998877665544332211',
              'privateKey': '-----BEGIN RSA PRIVATE KEY-----',
              'authToken': 'bearer_token_xyz',
              'accessToken': 'access_token_123',
              'refreshToken': 'refresh_token_456',
              'passphrase': 'passphrase_secret',
              'secret': 'nested_secret_val',
            },
          },
          'sensorList': [
            {'apiKey': 'nested_key_1', 'publicName': 'Sensor 1'},
            {'wifi_password': 'pass_2', 'publicName': 'Sensor 2'},
          ],
          'auth_credential_key': 'stripped_root_secret',
        };

        final sanitized = SecretSanitizer.sanitizeMap(rawData);

        // Non-sensitive data preserved
        expect(sanitized['deviceModel'], equals('LM-Pro-2026'));
        final net = sanitized['network'] as Map<String, dynamic>;
        expect(net['ssid'], equals('HomeOffice_5G'));
        final list = sanitized['sensorList'] as List<dynamic>;
        expect(list[0]['publicName'], equals('Sensor 1'));
        expect(list[1]['publicName'], equals('Sensor 2'));
        expect(sanitized.containsKey('auth_credential_key'), isFalse);

        // All sensitive fields completely scrubbed
        expect(net.containsKey('wifiPassword'), isFalse);
        final sec = net['security'] as Map<String, dynamic>;
        expect(sec.containsKey('apiKey'), isFalse);
        expect(sec.containsKey('privateKey'), isFalse);
        expect(sec.containsKey('authToken'), isFalse);
        expect(sec.containsKey('accessToken'), isFalse);
        expect(sec.containsKey('refreshToken'), isFalse);
        expect(sec.containsKey('passphrase'), isFalse);
        expect(sec.containsKey('secret'), isFalse);
        expect(list[0].containsKey('apiKey'), isFalse);
        expect(list[1].containsKey('wifi_password'), isFalse);
      });

      test(
          '2.2 SmartDevice.toJson() and fromJson() enforce deep secret stripping',
          () {
        final device = SmartDevice(
          id: 'dev-sec-nested',
          name: 'Secure Camera',
          roomId: 'Living Room',
          type: DeviceType.security,
          isOn: true,
          customData: {
            'firmware': 'v4.0.1',
            'config': {
              'authToken': 'bearer_auth_nested',
              'apiKey': 'nested_key',
              'wifiPassword': 'secret_password_here',
            },
            'direct_auth_token': 'root_token',
          },
        );

        final json = device.toJson();
        final custom = json['customData'] as Map<String, dynamic>;
        expect(custom['firmware'], equals('v4.0.1'));
        final config = custom['config'] as Map<String, dynamic>;
        expect(config.containsKey('authToken'), isFalse);
        expect(config.containsKey('apiKey'), isFalse);
        expect(config.containsKey('wifiPassword'), isFalse);
        expect(custom.containsKey('direct_auth_token'), isFalse);

        // fromJson sanitization
        final restored = SmartDevice.fromJson({
          'id': 'dev-sec-nested',
          'name': 'Secure Camera',
          'roomId': 'Living Room',
          'type': 'security',
          'customData': {
            'wifiPassword': 'never_store_this',
            'publicInfo': 'visible',
          },
        });
        expect(restored.customData.containsKey('wifiPassword'), isFalse);
        expect(restored.customData['publicInfo'], equals('visible'));
      });

      test(
          '2.3 exportBackupJson and saveHomeState scrub sensitive fields across all entities',
          () async {
        final demo = persistenceManager.createDemoState();
        final devWithSecrets = demo.devices.first.copyWith(
          customData: {
            'hardwareRev': 'revB',
            'password': 'bad_password',
            'accessToken': 'bad_access_token',
            'refreshToken': 'bad_refresh_token',
          },
        );
        await persistenceManager
            .saveDevices([devWithSecrets, ...demo.devices.skip(1)]);

        // Check persistent JSON in storage
        final storedJson =
            await storage.getString(HomePersistenceManager.storageKey);
        expect(storedJson, isNotNull);
        expect(storedJson!.contains('bad_password'), isFalse);
        expect(storedJson.contains('bad_access_token'), isFalse);
        expect(storedJson.contains('bad_refresh_token'), isFalse);
        expect(storedJson.contains('revB'), isTrue);

        // Check backup export
        final exported = await backupService.exportBackupJson(
            persistenceManager: persistenceManager);
        expect(exported.contains('bad_password'), isFalse);
        expect(exported.contains('bad_access_token'), isFalse);
        expect(exported.contains('bad_refresh_token'), isFalse);
        expect(exported.contains('revB'), isTrue);
      });

      test(
          '2.4 Simulated Wi-Fi passwords entered during onboarding never reach storage or backup',
          () async {
        final mockRepo = MockDeviceRepository();
        final mockProv = MockProvisioningService(stepDelay: Duration.zero);
        final onboardingNotifier = OnboardingNotifier(
          deviceRepository: mockRepo,
          provisioningService: mockProv,
        );

        const targetDiscovered = DiscoveredDevice(
          id: 'dev-onboard-test',
          name: 'Smart Socket Onboarding',
          type: DeviceType.socket,
          rssi: -45,
        );
        onboardingNotifier.selectDevice(targetDiscovered);

        const simulatedWifiPassword = 'SecretWifiPasswordFromUser!2026';

        await onboardingNotifier.provision(
          ssid: 'MyHomeMeshWifi',
          password: simulatedWifiPassword,
        );

        // Verify device in repository does not store wifi password in customData
        final registeredDevice = mockRepo.devices.firstWhere(
          (d) => d.id == 'dev-onboard-test',
        );
        expect(registeredDevice.customData.containsValue(simulatedWifiPassword),
            isFalse);

        // Persist to persistence manager and verify
        await persistenceManager.saveDevices([registeredDevice]);
        final stored =
            await storage.getString(HomePersistenceManager.storageKey);
        expect(stored!.contains(simulatedWifiPassword), isFalse);

        // Backup export verify
        final backup = await backupService.exportBackupJson(
            persistenceManager: persistenceManager);
        expect(backup.contains(simulatedWifiPassword), isFalse);
      });
    });

    // =========================================================================
    // SECTION 3: FEATURE C — ATOMIC BACKUP RESTORE WITH COMPENSATING ROLLBACK
    // =========================================================================
    group('3. Feature C — Atomic Backup Restore with Compensating Rollback',
        () {
      test(
          '3.1 Full pipeline: parse -> validate -> normalize -> verify -> apply candidate state',
          () async {
        await persistenceManager.loadHomeState();

        final validBackupJson = jsonEncode({
          'metadata': {
            'schemaVersion': 6,
            'lumivoVersion': '0.8.0',
            'exportedAt': DateTime.now().toIso8601String(),
          },
          'homes': [
            {
              'id': 'home-restored',
              'name': 'Restored Mountain Retreat',
              'address': '77 Summit Way',
              'role': 'Owner',
              'isCurrent': true,
              'tariffRate': 0.18,
              'currency': 'USD',
            }
          ],
          'rooms': [
            {
              'id': 'room-great-hall',
              'name': 'Great Hall',
              'homeId': 'home-restored',
            }
          ],
          'devices': [
            {
              'id': 'dev-fireplace',
              'name': 'Electric Fireplace',
              'roomId': 'room-great-hall',
              'type': 'socket',
              'isOn': true,
              'powerUsageWatts': 1200.0,
              'homeId': 'home-restored',
            }
          ],
          'scenes': [
            {
              'id': 'scene-fire',
              'name': 'Warm Glow',
              'homeId': 'home-restored',
              'actions': [
                {
                  'deviceId': 'dev-fireplace',
                  'commandType': 'setPower',
                  'value': true,
                }
              ],
            }
          ],
          'automations': [],
        });

        final success = await backupService.restoreBackup(
          jsonString: validBackupJson,
          persistenceManager: persistenceManager,
        );

        expect(success, isTrue);

        final restored = await persistenceManager.loadHomeState();
        expect(restored.currentHomeId, equals('home-restored'));
        expect(restored.homes.length, equals(1));
        expect(restored.homes.first.name, equals('Restored Mountain Retreat'));
        expect(restored.rooms.first.id, equals('room-great-hall'));
        expect(restored.devices.first.id, equals('dev-fireplace'));
        expect(restored.scenes.first.id, equals('scene-fire'));
      });

      test(
          '3.2 Pre-restore snapshot preserves state and rolls back cleanly on invalid candidate',
          () async {
        final preState = await persistenceManager.loadHomeState();
        final preHomesCount = preState.homes.length;
        final preDevicesCount = preState.devices.length;
        final preHomeId = preState.currentHomeId;

        // Candidate with referential integrity failure (scene references missing device)
        final brokenCandidateJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'homes': [
            {'id': 'home-temp', 'name': 'Temp Home'}
          ],
          'rooms': [
            {'id': 'room-temp', 'name': 'Temp Room'}
          ],
          'devices': [
            {'id': 'dev-temp-1', 'name': 'Temp Bulb', 'roomId': 'room-temp'}
          ],
          'scenes': [
            {
              'id': 'scene-broken',
              'name': 'Broken Scene',
              'actions': [
                {
                  'deviceId': 'ghost-device-not-present',
                  'commandType': 'setPower',
                  'value': true
                }
              ],
            }
          ],
          'automations': [],
        });

        final success = await backupService.restoreBackup(
          jsonString: brokenCandidateJson,
          persistenceManager: persistenceManager,
        );

        expect(success, isFalse);

        // State rolled back cleanly to pre-restore snapshot
        final postState = await persistenceManager.loadHomeState();
        expect(postState.homes.length, equals(preHomesCount));
        expect(postState.devices.length, equals(preDevicesCount));
        expect(postState.currentHomeId, equals(preHomeId));
      });

      test(
          '3.3 Concurrency lock guards restore execution against concurrent restore operations',
          () async {
        await persistenceManager.loadHomeState();

        final validBackupJson = jsonEncode({
          'metadata': {'schemaVersion': 6},
          'homes': [
            {'id': 'home-concur', 'name': 'Concurrent Test Home'}
          ],
          'rooms': [
            {'id': 'room-c', 'name': 'C Room'}
          ],
          'devices': [
            {'id': 'dev-c', 'name': 'C Device', 'roomId': 'room-c'}
          ],
          'scenes': [],
          'automations': [],
        });

        // Fire first restore
        final future1 = backupService.restoreBackup(
          jsonString: validBackupJson,
          persistenceManager: persistenceManager,
        );

        // Simultaneous second restore attempt while lock is held
        // In Dart single thread event loop, we can test that when isRestoring is true, restore returns false
        expect(BackupRestoreService.isRestoring, isTrue);
        final concurrentResult = await backupService.restoreBackup(
          jsonString: validBackupJson,
          persistenceManager: persistenceManager,
        );
        expect(concurrentResult, isFalse);

        final result1 = await future1;
        expect(result1, isTrue);
        expect(BackupRestoreService.isRestoring, isFalse);
      });
    });

    // =========================================================================
    // SECTION 4: FEATURE D — STORAGE RESILIENCE & CORRUPT RECOVERY
    // =========================================================================
    group('4. Feature D — Storage Resilience & Corrupt Recovery', () {
      test(
          '4.1 Recover valid independent records when encountering corrupted records in collections',
          () async {
        // Construct payload with 3 valid devices and 1 corrupt device record (e.g. invalid type or structure)
        final mixedPayload = {
          'schemaVersion': 6,
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
            }
          ],
          'rooms': [
            {'id': 'room-1', 'name': 'Room 1', 'iconName': 'living_room'},
            {'invalid': 'room without id or name'}, // Corrupt room
            {'id': 'room-2', 'name': 'Room 2', 'iconName': 'kitchen'},
          ],
          'devices': [
            {
              'id': 'dev-good-1',
              'name': 'Good Bulb 1',
              'roomId': 'room-1',
              'type': 'light',
              'isOn': true,
              'homeId': 'home-default',
            },
            {
              'id': 'dev-corrupted',
              'missing_required_fields': true, // Corrupt device
            },
            {
              'id': 'dev-good-2',
              'name': 'Good Fan 2',
              'roomId': 'room-2',
              'type': 'fan',
              'isOn': false,
              'homeId': 'home-default',
            },
          ],
        };

        await storage.setString(
          HomePersistenceManager.storageKey,
          jsonEncode(mixedPayload),
        );

        final state = await persistenceManager.loadHomeState();

        // Verifies that the 2 valid devices and 2 valid rooms were successfully recovered
        expect(state.devices.length, equals(2));
        expect(state.devices.any((d) => d.id == 'dev-good-1'), isTrue);
        expect(state.devices.any((d) => d.id == 'dev-good-2'), isTrue);
        expect(state.devices.any((d) => d.id == 'dev-corrupted'), isFalse);

        expect(state.rooms.length, equals(2));
        expect(state.rooms.any((r) => r.id == 'room-1'), isTrue);
        expect(state.rooms.any((r) => r.id == 'room-2'), isTrue);
      });

      test(
          '4.2 Truncated or broken primary JSON recovers safely from snapshot backup',
          () async {
        final preState = persistenceManager.createDemoState().copyWith(
          currentHomeId: 'home-snapshot-test',
          homes: [
            const Home(
              id: 'home-snapshot-test',
              name: 'Snapshot Preserved Home',
              address: '99 Cloud St',
              role: 'Owner',
              isCurrent: true,
              tariffRate: 0.15,
              currency: 'USD',
            )
          ],
        );
        await persistenceManager.saveHomeState(preState);

        // Verify snapshot backup was saved
        final meta = await persistenceManager.getSnapshotMetadata();
        expect(meta, isNotNull);
        expect(meta!['homeCount'], equals(1));
        expect(meta['schemaVersion'], equals(6));

        // Now simulate corrupted primary storage key (truncated write or syntax corruption)
        await storage.setString(
          HomePersistenceManager.storageKey,
          '{"schemaVersion": 6, "homes": [{"id": "broken',
        );

        // Load home state should recover from snapshot backup rather than wiping to factory demo
        final freshManager = HomePersistenceManager(storage: storage);
        final recovered = await freshManager.loadHomeState();

        expect(recovered.homes.length, equals(1));
        expect(recovered.homes.first.name, equals('Snapshot Preserved Home'));
        expect(recovered.currentHomeId, equals('home-snapshot-test'));
      });

      test(
          '4.3 QuotaExceededError resilience: prunes historical records and retries write',
          () async {
        final faultStorage = FaultInjectingStorageAdapter();
        final faultManager = HomePersistenceManager(storage: faultStorage);

        final state = faultManager.createDemoState().copyWith(
              activityEvents: List.generate(
                50,
                (i) => ActivityEvent(
                  id: 'evt-hist-$i',
                  title: 'Heavy Event $i',
                  description: 'Detailed description for event $i',
                  timestamp: DateTime.now(),
                  homeId: 'home-default',
                ),
              ),
              commandRecords: List.generate(
                50,
                (i) => CommandRecord(
                  requestId: 'cmd-hist-$i',
                  deviceId: 'dev-1',
                  type: DeviceCommandType.setPower,
                  value: true,
                  timestamp: DateTime.now(),
                  status: CommandStatus.confirmed,
                  homeId: 'home-default',
                ),
              ),
            );

        // Arm fault storage to throw QuotaExceededError on first primary write
        faultStorage.shouldThrowQuotaError = true;

        await faultManager.saveHomeState(state);

        // Persistence manager should catch the quota error, prune historical records to 10 entries, and retry write
        final savedJson =
            await faultStorage.getString(HomePersistenceManager.storageKey);
        expect(savedJson, isNotNull);
        final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
        final events = decoded['activityEvents'] as List;
        final commands = decoded['commandRecords'] as List;
        expect(events.length, lessThanOrEqualTo(10));
        expect(commands.length, lessThanOrEqualTo(10));
      });

      test(
          '4.4 Backward migration compatibility preserved across legacy schemas V1 to V6',
          () async {
        // V1 schema with device and room
        final v1Json = jsonEncode({
          'devices': [
            {
              'id': 'legacy-lamp',
              'name': 'Legacy Lamp',
              'roomId': 'Living Room',
              'type': 'light',
              'isOn': true,
              'brightness': 80,
            }
          ],
          'rooms': [
            {
              'id': 'Living Room',
              'name': 'Living Room',
              'iconName': 'living_room'
            }
          ],
        });
        await storage.setString(
            HomePersistenceManager.legacyStorageKey, v1Json);

        final loaded = await persistenceManager.loadHomeState();
        expect(loaded.schemaVersion, equals(6));
        expect(loaded.devices.any((d) => d.id == 'legacy-lamp'), isTrue);
        expect(loaded.devices.first.homeId, equals('home-default'));
        expect(loaded.homes.isNotEmpty, isTrue);
      });
    });

    // =========================================================================
    // SECTION 5: FEATURE E — CSV FORMULA INJECTION DEFENSE (CWE-1236)
    // =========================================================================
    group('5. Feature E — CSV Formula Injection Defense', () {
      test(
          '5.1 Dangerous formula triggers (=, +, -, @, \\t, \\r) are neutralized by prepending single quote',
          () {
        expect(EnergyInsightsService.sanitizeCsvCell('=SUM(A1:A10)'),
            equals("'=SUM(A1:A10)"));
        expect(EnergyInsightsService.sanitizeCsvCell('+cmd|/c calc'),
            equals("'+cmd|/c calc"));
        expect(EnergyInsightsService.sanitizeCsvCell('-123+456'),
            equals("'-123+456"));
        expect(
            EnergyInsightsService.sanitizeCsvCell(
                '@HYPERLINK("http://evil.com")'),
            equals("'@HYPERLINK(\"http://evil.com\")"));
        expect(EnergyInsightsService.sanitizeCsvCell('\tTabInjectedCell'),
            equals("'\tTabInjectedCell"));
        expect(EnergyInsightsService.sanitizeCsvCell('\rCarriageInjectedCell'),
            equals("'\rCarriageInjectedCell"));

        // Safe normal cells remain un-prefixed
        expect(EnergyInsightsService.sanitizeCsvCell('Living Room Light'),
            equals('Living Room Light'));
        expect(EnergyInsightsService.sanitizeCsvCell('Kitchen AC'),
            equals('Kitchen AC'));
      });

      test(
          '5.2 EnergyInsightsService.exportEnergyCsv neutralizes malicious device and room names',
          () {
        final maliciousReport = EnergyReport(
          period: 'day',
          totalKwh: 25.5,
          totalCost: 3.82,
          tariff: 0.15,
          previousPeriodKwh: 24.0,
          percentChange: 6.25,
          deviceBreakdown: [
            const EnergyBreakdownItem(
              id: 'dev-exploit-1',
              name: '=cmd|"/C calc"!A0',
              category: 'device',
              wattage: 1200.0,
              kwh: 28.8,
              cost: 4.32,
            ),
            const EnergyBreakdownItem(
              id: 'dev-exploit-2',
              name: '+12345 Dangerous Device',
              category: 'device',
              wattage: 50.0,
              kwh: 1.2,
              cost: 0.18,
            ),
            const EnergyBreakdownItem(
              id: 'dev-exploit-3',
              name: '-Negative Wattage Item',
              category: 'device',
              wattage: 10.0,
              kwh: 0.24,
              cost: 0.036,
            ),
            const EnergyBreakdownItem(
              id: 'dev-exploit-4',
              name: '@HYPERLINK("http://attacker.com")',
              category: 'device',
              wattage: 5.0,
              kwh: 0.12,
              cost: 0.018,
            ),
          ],
          roomBreakdown: [
            const EnergyBreakdownItem(
              id: 'room-exploit-1',
              name: '=SUM(1+1)',
              category: 'room',
              wattage: 1265.0,
              kwh: 30.36,
              cost: 4.554,
            ),
          ],
          generatedAt: DateTime(2026, 10, 26, 12, 0),
        );

        final csv = energyService.exportEnergyCsv(maliciousReport);

        // Simulated banner and RFC headers preserved
        expect(
            csv,
            contains(
                '# Lumivo Energy Report - Generated: 2026-10-26T12:00:00.000'));
        expect(csv, contains('# Notice: All figures are simulated estimates.'));
        expect(
            csv,
            contains(
                'Period,Category,Name,Wattage_W,Consumption_kWh,Estimated_Cost,Tariff'));

        // All formula execution triggers strictly prepended with single quote `'`
        expect(csv, contains('\'=cmd|""/C calc""!A0'));
        expect(csv, contains('\'+12345 Dangerous Device'));
        expect(csv, contains('\'-Negative Wattage Item'));
        expect(csv, contains('\'@HYPERLINK'));
        expect(csv, contains('\'=SUM(1+1)'));

        // Never contains raw unescaped `=cmd` at start of a cell
        expect(csv.contains(',=cmd'), isFalse);
        expect(csv.contains(',+12345'), isFalse);
        expect(csv.contains(',-Negative'), isFalse);
        expect(csv.contains(',@HYPERLINK'), isFalse);
        expect(csv.contains(',=SUM'), isFalse);
      });

      test(
          '5.3 EnergyInsightsEngine.exportToCsv also neutralizes formula injection',
          () {
        final maliciousReport = EnergyReport(
          period: 'day',
          totalKwh: 10.0,
          totalCost: 1.5,
          tariff: 0.15,
          previousPeriodKwh: 9.5,
          percentChange: 5.26,
          deviceBreakdown: [
            const EnergyBreakdownItem(
              id: 'dev-injected',
              name: '=2+5*cmd',
              category: 'device',
              wattage: 100.0,
              kwh: 2.4,
              cost: 0.36,
            ),
          ],
          roomBreakdown: [
            const EnergyBreakdownItem(
              id: 'room-injected',
              name: '-Calc Room',
              category: 'room',
              wattage: 100.0,
              kwh: 2.4,
              cost: 0.36,
            ),
          ],
          generatedAt: DateTime(2026, 10, 26, 14, 0),
        );

        final csv = EnergyInsightsEngine.exportToCsv(maliciousReport);

        expect(
            csv,
            contains(
                'Timestamp,Category,ID,Name,Power (W),Energy (kWh),Cost (\$),Tariff (\$/kWh)'));
        expect(csv, contains('\'=2+5*cmd'));
        expect(csv, contains('\'-Calc Room'));
        expect(csv.contains(',"=2+5*cmd"'), isFalse);
        expect(csv.contains(',"-Calc Room"'), isFalse);
      });
    });
  });
}
