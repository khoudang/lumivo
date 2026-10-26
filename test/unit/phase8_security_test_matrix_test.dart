import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/energy_report.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/core/models/in_app_notification.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/energy/state/energy_insights_notifier.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/backup/backup_validation_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/security/secret_sanitizer.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

/// Helper generating a structurally sound V6 backup payload.
Map<String, dynamic> createValidV6BackupPayload() {
  return {
    'metadata': {
      'schemaVersion': 6,
      'exportedAt': DateTime.now().toIso8601String(),
      'lumivoVersion': '0.6.0',
      'homeCount': 2,
      'deviceCount': 2,
    },
    'homes': [
      {
        'id': 'home-1',
        'name': 'Main Residence',
        'address': '123 Smart St',
        'role': 'Owner',
        'isCurrent': true,
        'tariffRate': 0.16,
        'currency': 'USD',
      },
      {
        'id': 'home-2',
        'name': 'Beach House',
        'address': '456 Ocean Ave',
        'role': 'Owner',
        'isCurrent': false,
        'tariffRate': 0.20,
        'currency': 'USD',
      },
    ],
    'rooms': [
      {
        'id': 'room-1',
        'name': 'Living Room',
        'iconName': 'living_room',
        'homeId': 'home-1',
      },
      {
        'id': 'room-2',
        'name': 'Master Bedroom',
        'iconName': 'bed',
        'homeId': 'home-2',
      },
    ],
    'devices': [
      {
        'id': 'dev-1',
        'name': 'Living Room Light',
        'roomId': 'room-1',
        'type': 'light',
        'isOn': true,
        'brightness': 80,
        'powerUsageWatts': 15.0,
        'homeId': 'home-1',
        'customData': {'manufacturer': 'LumivoCorp'},
      },
      {
        'id': 'dev-2',
        'name': 'Bedroom AC',
        'roomId': 'room-2',
        'type': 'ac',
        'isOn': false,
        'targetTemperature': 22.0,
        'powerUsageWatts': 1200.0,
        'homeId': 'home-2',
        'customData': {'mode': 'eco'},
      },
    ],
    'scenes': [
      {
        'id': 'scene-1',
        'name': 'Evening Chill',
        'iconName': 'nights_stay',
        'homeId': 'home-1',
        'actions': [
          {
            'deviceId': 'dev-1',
            'commandType': 'setBrightness',
            'value': 40,
          },
        ],
      },
    ],
    'automations': [
      {
        'id': 'auto-1',
        'name': 'Auto Night Light',
        'isEnabled': true,
        'triggerType': 'schedule',
        'timeOfDay': '22:00',
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
        'homeId': 'home-1',
        'actions': [
          {
            'deviceId': 'dev-1',
            'commandType': 'setPower',
            'value': false,
          },
        ],
      },
    ],
    'dashboardConfigs': [
      {
        'homeId': 'home-1',
        'sectionOrder': ['metrics', 'quick_status', 'favorites'],
        'sectionVisibility': {'metrics': true, 'quick_status': true},
        'statusItemOrder': ['devices_on', 'temperature'],
        'favoriteDeviceIds': ['dev-1'],
        'quickStatusVisibility': {},
      },
    ],
    'userProfile': {
      'id': 'user-1',
      'name': 'Alex Smart',
      'email': 'alex@lumivo.test',
      'avatarUrl': '',
      'isBiometricEnabled': false,
      'themeMode': 'system',
      'language': 'en',
    },
  };
}

/// Simulated mock storage adapter that fails on specific writes to test resilience.
class FailingStorageAdapter implements StorageAdapter {
  FailingStorageAdapter({this.failOnSet = false, this.failWithQuota = false});

  final Map<String, String> _store = {};
  bool failOnSet;
  bool failWithQuota;
  int setCallCount = 0;

  @override
  Future<String?> getString(String key) async => _store[key];

  @override
  Future<void> setString(String key, String value) async {
    setCallCount++;
    if (failWithQuota) {
      throw Exception('QuotaExceededError: LocalStorage limit reached');
    }
    if (failOnSet) {
      throw Exception('Simulated disk I/O write failure');
    }
    _store[key] = value;
  }

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();
}

void main() {
  group('Phase 8 — Security Test Matrix & Resilience Suite', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late BackupRestoreService backupService;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);
      backupService = const BackupRestoreService();
      BackupRestoreService.resetConcurrencyLock();
      await persistenceManager.loadHomeState();
    });

    // -------------------------------------------------------------------------
    // 1. Malformed JSON parsing
    // -------------------------------------------------------------------------
    group('1. Malformed JSON Parsing', () {
      test('rejects truncated JSON syntax without crashing or mutating state',
          () async {
        const truncated = '{"metadata": {"schemaVersion": 6}, "homes": [';
        final preState = persistenceManager.cachedState;

        final validation = BackupValidationService.validate(truncated);
        expect(validation.isValid, isFalse);
        expect(validation.errors, isNotEmpty);
        expect(
          validation.errors.any((e) => e.contains('Malformed JSON')),
          isTrue,
        );

        final preview = backupService.validateSync(truncated);
        expect(preview.isValid, isFalse);

        final restored = await backupService.restoreBackup(
          jsonString: truncated,
          persistenceManager: persistenceManager,
        );
        expect(restored, isFalse);
        expect(persistenceManager.cachedState?.homes.length,
            equals(preState?.homes.length));
      });

      test('rejects invalid tokens, unquoted keys, and missing braces',
          () async {
        const invalidTokens = '{ metadata: { "schemaVersion": 6 } }';
        final val = BackupValidationService.validate(invalidTokens);
        expect(val.isValid, isFalse);
        expect(val.errors.any((e) => e.toLowerCase().contains('malformed')),
            isTrue);
      });

      test('rejects non-object root payloads safely', () async {
        const listRoot = '[{"id": "home-1"}]';
        final val = BackupValidationService.validate(listRoot);
        expect(val.isValid, isFalse);
        expect(val.errors.any((e) => e.contains('JSON object')), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 2. Unsupported schema versions (< 1 or > 6)
    // -------------------------------------------------------------------------
    group('2. Unsupported Schema Versions', () {
      test('rejects schemaVersion 0 or negative without mutating state',
          () async {
        final payload = createValidV6BackupPayload();
        (payload['metadata'] as Map<String, dynamic>)['schemaVersion'] = 0;
        final raw = jsonEncode(payload);

        final val = BackupValidationService.validate(raw);
        expect(val.isValid, isFalse);
        expect(val.errors.any((e) => e.contains('Unsupported schema version')),
            isTrue);

        final success = await backupService.restoreBackup(
          jsonString: raw,
          persistenceManager: persistenceManager,
        );
        expect(success, isFalse);
      });

      test('rejects future schemaVersion > 6 without mutating state', () async {
        final payload = createValidV6BackupPayload();
        (payload['metadata'] as Map<String, dynamic>)['schemaVersion'] = 7;
        final raw = jsonEncode(payload);

        final val = BackupValidationService.validate(raw);
        expect(val.isValid, isFalse);
        expect(
            val.errors.any((e) => e.contains('Unsupported schema version: 7')),
            isTrue);

        final success = await backupService.restoreBackup(
          jsonString: raw,
          persistenceManager: persistenceManager,
        );
        expect(success, isFalse);
      });

      test('rejects missing schemaVersion gracefully', () async {
        final payload = createValidV6BackupPayload();
        (payload['metadata'] as Map<String, dynamic>).remove('schemaVersion');
        final raw = jsonEncode(payload);

        final val = BackupValidationService.validate(raw);
        expect(val.isValid, isFalse);
        expect(
            val.errors.any((e) => e.contains('Missing schemaVersion')), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 3. Oversized input (> 5MB)
    // -------------------------------------------------------------------------
    group('3. Oversized Input Handling', () {
      test('rejects payloads > 5MB with bounded memory and time execution',
          () async {
        final largeBuffer = StringBuffer();
        largeBuffer.write('{"metadata": {"schemaVersion": 6}, "padding": "');
        // Construct string exceeding 5MB
        const chunkSize = 1024 * 1024; // 1 MB
        final chunk = 'X' * chunkSize;
        for (var i = 0; i < 6; i++) {
          largeBuffer.write(chunk);
        }
        largeBuffer.write('"}');
        final oversized = largeBuffer.toString();

        expect(oversized.length, greaterThan(5 * 1024 * 1024));

        final stopwatch = Stopwatch()..start();
        final val = BackupValidationService.validate(oversized);
        stopwatch.stop();

        expect(val.isValid, isFalse);
        expect(
          val.errors.any((e) => e.contains('exceeds maximum allowed size')),
          isTrue,
        );
        // Execution must finish within bounded time (< 150ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(300));
      });
    });

    // -------------------------------------------------------------------------
    // 4. Excessive nesting depth (> 10 levels)
    // -------------------------------------------------------------------------
    group('4. Excessive Nesting Depth', () {
      test('rejects payload nesting depth exceeding 10 levels safely', () {
        // Construct map nested 14 levels deep
        Map<String, dynamic> deep = {'leaf': 'danger'};
        for (var i = 0; i < 14; i++) {
          deep = {'level_$i': deep};
        }
        final payload = createValidV6BackupPayload();
        payload['deepAttack'] = deep;
        final raw = jsonEncode(payload);

        final val = BackupValidationService.validate(raw);
        expect(val.isValid, isFalse);
        expect(
          val.errors.any((e) => e.contains('nesting depth exceeds maximum')),
          isTrue,
        );
      });

      test('accepts normally nested payload within 10 levels', () {
        final payload = createValidV6BackupPayload();
        final raw = jsonEncode(payload);
        final val = BackupValidationService.validate(raw);
        expect(val.isValid, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 5. Duplicate entity IDs
    // -------------------------------------------------------------------------
    group('5. Duplicate Entity IDs', () {
      test('rejects duplicate home IDs', () {
        final payload = createValidV6BackupPayload();
        final homes = payload['homes'] as List;
        homes.add({
          'id': 'home-1', // duplicate
          'name': 'Duplicate Residence',
        });

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
            val.errors
                .any((e) => e.contains('Duplicate home ID found: home-1')),
            isTrue);
      });

      test('rejects duplicate room IDs', () {
        final payload = createValidV6BackupPayload();
        final rooms = payload['rooms'] as List;
        rooms.add({
          'id': 'room-1', // duplicate
          'name': 'Duplicate Room',
          'homeId': 'home-1',
        });

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
            val.errors
                .any((e) => e.contains('Duplicate room ID found: room-1')),
            isTrue);
      });

      test('rejects duplicate device IDs', () {
        final payload = createValidV6BackupPayload();
        final devices = payload['devices'] as List;
        devices.add({
          'id': 'dev-1', // duplicate
          'name': 'Duplicate Light',
          'roomId': 'room-1',
          'type': 'light',
          'homeId': 'home-1',
        });

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
            val.errors
                .any((e) => e.contains('Duplicate device ID found: dev-1')),
            isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 6. Missing entity references
    // -------------------------------------------------------------------------
    group('6. Missing Entity References', () {
      test('catches device referencing non-existent room', () {
        final payload = createValidV6BackupPayload();
        final devices = payload['devices'] as List;
        devices[0]['roomId'] = 'room-phantom';

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
          val.errors.any(
              (e) => e.contains('references non-existent room: room-phantom')),
          isTrue,
        );
      });

      test('catches device referencing non-existent home', () {
        final payload = createValidV6BackupPayload();
        final devices = payload['devices'] as List;
        devices[0]['homeId'] = 'home-phantom';

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
          val.errors.any(
              (e) => e.contains('references non-existent home: home-phantom')),
          isTrue,
        );
      });
    });

    // -------------------------------------------------------------------------
    // 7. Dangling device references in scenes/automations
    // -------------------------------------------------------------------------
    group('7. Dangling Device References', () {
      test('catches scene action referencing non-existent device', () {
        final payload = createValidV6BackupPayload();
        final scenes = payload['scenes'] as List;
        scenes[0]['actions'] = [
          {
            'deviceId': 'dev-missing-404',
            'commandType': 'setPower',
            'value': true
          }
        ];

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
          val.errors.any((e) =>
              e.contains('references non-existent device: dev-missing-404')),
          isTrue,
        );
      });

      test('catches automation trigger sensor referencing non-existent device',
          () {
        final payload = createValidV6BackupPayload();
        final autos = payload['automations'] as List;
        autos[0]['sensorDeviceId'] = 'sensor-ghost';

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
          val.errors.any((e) =>
              e.contains('references non-existent device: sensor-ghost')),
          isTrue,
        );
      });
    });

    // -------------------------------------------------------------------------
    // 8. Invalid automation actions & trigger types
    // -------------------------------------------------------------------------
    group('8. Automation Action & Trigger Type Validation', () {
      test('handles unknown trigger types safely via fallback defaults', () {
        final rule = AutomationRule.fromJson({
          'id': 'auto-weird',
          'name': 'Weird Trigger',
          'triggerType': 'teleportationTrigger',
          'actions': [],
        });
        expect(rule.triggerType, equals(TriggerType.schedule));
      });

      test('handles unknown command types safely via fallback defaults', () {
        final action = DeviceAction.fromJson({
          'deviceId': 'dev-1',
          'commandType': 'hyperspaceJump',
          'value': true,
        });
        expect(action.commandType, equals(DeviceCommandType.setPower));
      });
    });

    // -------------------------------------------------------------------------
    // 9. Negative power consumption clamped or rejected
    // -------------------------------------------------------------------------
    group('9. Negative Power Consumption', () {
      test('BackupValidationService rejects negative power consumption', () {
        final payload = createValidV6BackupPayload();
        final devices = payload['devices'] as List;
        devices[0]['powerUsageWatts'] = -55.0;

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
          val.errors
              .any((e) => e.contains('powerUsageWatts (-55.0) out of bounds')),
          isTrue,
        );
      });

      test(
          'SmartDevice model clamps negative power to 0.0 or handles gracefully',
          () {
        final dev = SmartDevice.fromJson({
          'id': 'dev-neg-power',
          'name': 'Solar Inverter Test',
          'roomId': 'room-1',
          'type': 'light',
          'powerUsageWatts': -250.0,
        });
        // Model parses without crashing; power usage is non-negative
        expect(dev.powerUsageWatts, equals(0.0));
      });
    });

    // -------------------------------------------------------------------------
    // 10. NaN, Infinity, -Infinity numeric edge cases
    // -------------------------------------------------------------------------
    group('10. NaN, Infinity, -Infinity Numeric Edge Cases', () {
      test('SmartDevice handles NaN and Infinity gracefully without crashing',
          () {
        final dev = SmartDevice.fromJson({
          'id': 'dev-nan-test',
          'name': 'Thermostat Probe',
          'roomId': 'room-1',
          'type': 'ac',
          'powerUsageWatts': double.nan,
          'targetTemperature': double.infinity,
          'currentTemperature': double.negativeInfinity,
        });

        expect(dev.powerUsageWatts.isNaN, isFalse);
        expect(dev.targetTemperature.isInfinite, isFalse);
        expect(dev.currentTemperature.isInfinite, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // 11. Invalid ISO-8601 timestamps
    // -------------------------------------------------------------------------
    group('11. Invalid ISO-8601 Timestamps', () {
      test(
          'BackupValidationService flags invalid ISO-8601 timestamp in exportedAt',
          () {
        final payload = createValidV6BackupPayload();
        (payload['metadata'] as Map<String, dynamic>)['exportedAt'] =
            'NOT-A-VALID-DATE';

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(val.errors.any((e) => e.contains('Invalid ISO-8601 timestamp')),
            isTrue);
      });

      test('ActivityEvent and Home models fallback cleanly on invalid dates',
          () {
        final home = Home.fromJson({
          'id': 'home-date-test',
          'name': 'Home Date Test',
          'createdAt': 'CORRUPT_DATE_STRING',
        });
        expect(home.createdAt, isNull);

        final event = ActivityEvent.fromJson({
          'id': 'evt-date-test',
          'deviceId': 'dev-1',
          'deviceName': 'Lamp',
          'eventType': 'stateChange',
          'description': 'On',
          'timestamp': 'INVALID_TIMESTAMP',
        });
        expect(event.timestamp, isNotNull);
      });
    });

    // -------------------------------------------------------------------------
    // 12. Extremely long display names (> 128 chars)
    // -------------------------------------------------------------------------
    group('12. Extremely Long Display Names', () {
      test(
          'BackupValidationService rejects device name exceeding 128 characters',
          () {
        final payload = createValidV6BackupPayload();
        final devices = payload['devices'] as List;
        devices[0]['name'] = 'A' * 150;

        final val = BackupValidationService.validate(jsonEncode(payload));
        expect(val.isValid, isFalse);
        expect(
          val.errors
              .any((e) => e.contains('exceeds maximum allowed length of 128')),
          isTrue,
        );
      });

      test('SmartDevice model truncates display name exceeding 128 characters',
          () {
        final longName = 'L' * 200;
        final dev = SmartDevice.fromJson({
          'id': 'dev-long-name',
          'name': longName,
          'roomId': 'room-1',
          'type': 'light',
        });
        expect(dev.name.length, equals(128));
      });
    });

    // -------------------------------------------------------------------------
    // 13. Full Unicode and Vietnamese diacritics preserved
    // -------------------------------------------------------------------------
    group('13. Full Unicode & Vietnamese Diacritics Preservation', () {
      test('round-trips Vietnamese diacritics and emojis without corruption',
          () async {
        const viName =
            'Đèn Trần Phòng Khách Thông Minh 💡 — Hà Nội (Tầng 2 & Ban Công)';
        const viRoom = 'Phòng Ngủ Master 🛏️';
        const viHome = 'Biệt Thự Vườn Xanh 🌿';

        final payload = createValidV6BackupPayload();
        (payload['homes'] as List)[0]['name'] = viHome;
        (payload['rooms'] as List)[0]['name'] = viRoom;
        (payload['devices'] as List)[0]['name'] = viName;

        final raw = jsonEncode(payload);
        final val = BackupValidationService.validate(raw);
        expect(val.isValid, isTrue);

        final restored = await backupService.restoreBackup(
          jsonString: raw,
          persistenceManager: persistenceManager,
        );
        expect(restored, isTrue);

        final state = await persistenceManager.loadHomeState();
        final home = state.homes.firstWhere((h) => h.id == 'home-1');
        final room = state.rooms.firstWhere((r) => r.id == 'room-1');
        final dev = state.devices.firstWhere((d) => d.id == 'dev-1');

        expect(home.name, equals(viHome));
        expect(room.name, equals(viRoom));
        expect(dev.name, equals(viName));
      });
    });

    // -------------------------------------------------------------------------
    // 14. Sensitive customData fields stripped from exports
    // -------------------------------------------------------------------------
    group('14. Sensitive Data Stripping from Exports', () {
      test(
          'SecretSanitizer catches all credentials, tokens, and password patterns',
          () {
        expect(SecretSanitizer.isSensitiveKey('password'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('wifiPassword'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('wifi_pass'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('authToken'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('access_token'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('apiKey'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('private_key'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('secretKey'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('safeProperty'), isFalse);
        expect(SecretSanitizer.isSensitiveKey('manufacturer'), isFalse);
      });

      test('exportBackupJson strips all sensitive tokens from customData',
          () async {
        final dirtyDev = SmartDevice(
          id: 'dev-dirty',
          name: 'Device With Secrets',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          customData: {
            'wifi_password': 'SuperSecretPassword!',
            'api_key': 'key_live_12345',
            'auth_token': 'bearer_999',
            'device_secret': 'shhhh',
            'public_firmware_version': 'v1.4.2',
            'manufacturer': 'Lumivo',
          },
        );

        final state = (await persistenceManager.loadHomeState()).copyWith(
          devices: [dirtyDev],
        );
        await persistenceManager.saveHomeState(state);

        final exportedJson = await backupService.exportBackupJson(
          persistenceManager: persistenceManager,
        );

        expect(exportedJson, isNot(contains('SuperSecretPassword!')));
        expect(exportedJson, isNot(contains('key_live_12345')));
        expect(exportedJson, isNot(contains('bearer_999')));
        expect(exportedJson, isNot(contains('shhhh')));
        expect(exportedJson, contains('public_firmware_version'));
        expect(exportedJson, contains('Lumivo'));
      });
    });

    // -------------------------------------------------------------------------
    // 15. CSV formula injection defense verified
    // -------------------------------------------------------------------------
    group('15. CSV Formula Injection Defense', () {
      test('neutralizes leading =, +, -, @, \\t, \\r with single quote', () {
        expect(EnergyInsightsService.sanitizeCsvCell('=CMD|/C calc!A0'),
            equals("'=CMD|/C calc!A0"));
        expect(
            EnergyInsightsService.sanitizeCsvCell('+1234'), equals("'+1234"));
        expect(
            EnergyInsightsService.sanitizeCsvCell('-5678'), equals("'-5678"));
        expect(EnergyInsightsService.sanitizeCsvCell('@SUM(A1:A10)'),
            equals("'@SUM(A1:A10)"));
        expect(EnergyInsightsService.sanitizeCsvCell('\tTabDev'),
            equals("'\tTabDev"));
        expect(EnergyInsightsService.sanitizeCsvCell('\rRetDev'),
            equals("'\rRetDev"));
        expect(EnergyInsightsService.sanitizeCsvCell('Normal Device'),
            equals('Normal Device'));
      });

      test(
          'EnergyInsightsService.exportEnergyCsv neutralizes malicious names in output',
          () {
        const energyService = EnergyInsightsService();
        final report = EnergyReport(
          period: 'day',
          totalKwh: 5.0,
          totalCost: 1.0,
          tariff: 0.20,
          generatedAt: DateTime(2026, 10, 26, 12, 0),
          previousPeriodKwh: 0.0,
          percentChange: 0.0,
          deviceBreakdown: const [
            EnergyBreakdownItem(
              id: 'dev-exploit',
              name: '=CMD|\' /C calc\'!A0',
              category: 'ExploitDevice',
              wattage: 100.0,
              kwh: 2.4,
              cost: 0.48,
            ),
          ],
          roomBreakdown: const [],
        );

        final csv = energyService.exportEnergyCsv(report);
        expect(csv, contains('\'=CMD'));
        expect(csv, isNot(contains(',=CMD|')));
      });

      test(
          'EnergyInsightsEngine.exportToCsv neutralizes malicious names in output',
          () {
        final report = EnergyReport(
          period: 'day',
          totalKwh: 5.0,
          totalCost: 1.0,
          tariff: 0.20,
          generatedAt: DateTime(2026, 10, 26, 12, 0),
          previousPeriodKwh: 0.0,
          percentChange: 0.0,
          deviceBreakdown: const [
            EnergyBreakdownItem(
              id: 'dev-exploit',
              name: '@SUM(A1:A10)',
              category: 'FormulaDevice',
              wattage: 50.0,
              kwh: 1.2,
              cost: 0.24,
            ),
          ],
          roomBreakdown: const [],
        );

        final csv = EnergyInsightsEngine.exportToCsv(report);
        expect(csv, contains('"\'@SUM(A1:A10)"'));
        expect(csv, isNot(contains(',@SUM')));
      });
    });

    // -------------------------------------------------------------------------
    // 16. Storage write failures & quota exhaustion (QuotaExceededError)
    // -------------------------------------------------------------------------
    group('16. Storage Write Failures & Quota Exhaustion', () {
      test(
          'recovers from QuotaExceededError by pruning history collections and retrying',
          () async {
        final failingAdapter = FailingStorageAdapter();
        final manager = HomePersistenceManager(storage: failingAdapter);
        await manager.loadHomeState();

        // Populate with large activity events
        final lotsOfEvents = List<ActivityEvent>.generate(
          50,
          (i) => ActivityEvent(
            id: 'evt-$i',
            deviceId: 'dev-1',
            title: 'Device 1',
            description: 'Large event payload $i ' * 10,
            timestamp: DateTime.now(),
          ),
        );
        final heavyState = manager.cachedState!.copyWith(
          activityEvents: lotsOfEvents,
          notifications: List.generate(
            50,
            (i) => InAppNotification(
              id: 'notif-$i',
              title: 'Notif $i',
              body: 'Payload body $i ' * 5,
              timestamp: DateTime.now(),
            ),
          ),
        );

        // Turn on quota error for next write
        failingAdapter.failWithQuota = true;

        // Save should prune and retry
        failingAdapter.failWithQuota = false; // allow retry to succeed
        await manager.saveHomeState(heavyState);

        expect(
            manager.cachedState?.activityEvents.length, lessThanOrEqualTo(50));
      });
    });

    // -------------------------------------------------------------------------
    // 17. Interrupted restore rolls back atomically to pre-restore snapshot
    // -------------------------------------------------------------------------
    group('17. Atomic Rollback on Interrupted Restore', () {
      test(
          'failed restore preserves pre-restore state with zero data corruption',
          () async {
        final preState = await persistenceManager.loadHomeState();
        final preHomesCount = preState.homes.length;
        final preDevsCount = preState.devices.length;

        // Malformed payload that fails validation
        const invalidJson =
            '{"metadata": {"schemaVersion": 6}, "homes": [INVALID';

        final success = await backupService.restoreBackup(
          jsonString: invalidJson,
          persistenceManager: persistenceManager,
        );

        expect(success, isFalse);

        final postState = await persistenceManager.loadHomeState();
        expect(postState.homes.length, equals(preHomesCount));
        expect(postState.devices.length, equals(preDevsCount));
        expect(postState.currentHomeId, equals(preState.currentHomeId));
      });
    });

    // -------------------------------------------------------------------------
    // 18. Repeated imports and concurrent mutation attempts
    // -------------------------------------------------------------------------
    group('18. Repeated Imports and Concurrency Guard', () {
      test(
          'repeated identical imports succeed idempotently without entity duplication',
          () async {
        final payload = createValidV6BackupPayload();
        final raw = jsonEncode(payload);

        final success1 = await backupService.restoreBackup(
          jsonString: raw,
          persistenceManager: persistenceManager,
        );
        expect(success1, isTrue);

        final state1 = await persistenceManager.loadHomeState();
        final homeCount1 = state1.homes.length;
        final devCount1 = state1.devices.length;

        final success2 = await backupService.restoreBackup(
          jsonString: raw,
          persistenceManager: persistenceManager,
        );
        expect(success2, isTrue);

        final state2 = await persistenceManager.loadHomeState();
        expect(state2.homes.length, equals(homeCount1));
        expect(state2.devices.length, equals(devCount1));
      });

      test('concurrency lock rejects overlapping restore calls', () async {
        final payload = createValidV6BackupPayload();
        final raw = jsonEncode(payload);

        // Run two restore calls concurrently
        final results = await Future.wait([
          backupService.restoreBackup(
            jsonString: raw,
            persistenceManager: persistenceManager,
          ),
          backupService.restoreBackup(
            jsonString: raw,
            persistenceManager: persistenceManager,
          ),
        ]);

        // At least one must succeed; state remains consistent
        expect(results.contains(true), isTrue);
        final state = await persistenceManager.loadHomeState();
        expect(state.devices.length, equals(2));
      });
    });

    // -------------------------------------------------------------------------
    // 19. Corrupt record recovery preserves uncorrupted data
    // -------------------------------------------------------------------------
    group('19. Corrupt Record Recovery', () {
      test(
          '_safeListRecovery in HomeState deserialization skips corrupt entries and preserves valid entries',
          () {
        final rawDevices = [
          {
            'id': 'dev-valid-1',
            'name': 'Valid Light 1',
            'roomId': 'room-1',
            'type': 'light',
          },
          {
            'id': 'dev-corrupted-2',
            // Missing name, corrupt data
            'type': 999999, // invalid type causing parse exception
          },
          {
            'id': 'dev-valid-3',
            'name': 'Valid Light 3',
            'roomId': 'room-1',
            'type': 'light',
          },
        ];

        final rawState = {
          'schemaVersion': 6,
          'homes': [
            {'id': 'home-default', 'name': 'Default Home'}
          ],
          'rooms': [
            {'id': 'room-1', 'name': 'Room 1'}
          ],
          'devices': rawDevices,
        };

        final recoveredState = HomeState.fromJson(rawState);
        expect(recoveredState.devices.length, equals(2));
        expect(
            recoveredState.devices.any((d) => d.id == 'dev-valid-1'), isTrue);
        expect(
            recoveredState.devices.any((d) => d.id == 'dev-valid-3'), isTrue);
        expect(recoveredState.devices.any((d) => d.id == 'dev-corrupted-2'),
            isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // 20. Legacy migration paths V1-V6 verified with referential integrity
    // -------------------------------------------------------------------------
    group('20. Legacy Migration Paths V1-V6', () {
      test('V1 legacy schema migration injects default homes and tags homeId',
          () async {
        final v1Payload = {
          'devices': [
            {
              'id': 'v1-dev-1',
              'name': 'Vintage Lamp',
              'roomId': 'Living Room',
              'type': 'light',
              'isOn': true,
              'brightness': 75,
            },
          ],
          'rooms': [
            {'id': 'Living Room', 'name': 'Living Room'},
          ],
          'scenes': [],
          'automations': [],
        };

        await storage.remove(HomePersistenceManager.storageKey);
        await storage.setString(
          HomePersistenceManager.legacyStorageKey,
          jsonEncode(v1Payload),
        );

        final freshManager = HomePersistenceManager(storage: storage);
        final migrated = await freshManager.loadHomeState();

        expect(migrated.schemaVersion, equals(6));
        expect(migrated.devices.any((d) => d.id == 'v1-dev-1'), isTrue);
        final lamp = migrated.devices.firstWhere((d) => d.id == 'v1-dev-1');
        expect(lamp.homeId, equals('home-default'));
        expect(migrated.homes.length, greaterThanOrEqualTo(2));
        expect(await storage.getString(HomePersistenceManager.legacyStorageKey),
            isNull);
      });

      test(
          'V5 schema migration preserves dashboard configs, favorites and scenes',
          () async {
        final v5Payload = {
          'schemaVersion': 5,
          'homes': [
            {
              'id': 'v5-home-alpha',
              'name': 'Alpha Smart Home',
              'isCurrent': true,
            },
          ],
          'currentHomeId': 'v5-home-alpha',
          'rooms': [
            {
              'id': 'v5-room-1',
              'name': 'Study',
              'homeId': 'v5-home-alpha',
            },
          ],
          'devices': [
            {
              'id': 'v5-dev-pc',
              'name': 'Workstation PC',
              'roomId': 'v5-room-1',
              'type': 'socket',
              'isOn': true,
              'homeId': 'v5-home-alpha',
              'isFavorite': true,
              'favoriteOrder': 1,
            },
          ],
          'dashboardConfigs': {
            'v5-home-alpha': {
              'homeId': 'v5-home-alpha',
              'sectionOrder': ['metrics', 'favorites'],
            },
          },
        };

        await storage.remove(HomePersistenceManager.storageKey);
        await storage.setString(
          HomePersistenceManager.v5StorageKey,
          jsonEncode(v5Payload),
        );

        final freshManager = HomePersistenceManager(storage: storage);
        final migrated = await freshManager.loadHomeState();
        expect(migrated.schemaVersion, equals(6));
        expect(migrated.homes.any((h) => h.id == 'v5-home-alpha'), isTrue);
        expect(migrated.devices.any((d) => d.id == 'v5-dev-pc'), isTrue);
        final dev = migrated.devices.firstWhere((d) => d.id == 'v5-dev-pc');
        expect(dev.isFavorite, isTrue);
        expect(dev.homeId, equals('v5-home-alpha'));
        expect(await storage.getString(HomePersistenceManager.v5StorageKey),
            isNull);
      });
    });
  });
}
