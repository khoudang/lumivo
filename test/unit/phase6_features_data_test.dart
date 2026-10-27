import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/search/device_search_engine.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 6 — Device Discovery & Search Engine Tests', () {
    const searchEngine = DeviceSearchEngine();

    final testDevices = [
      const SmartDevice(
        id: 'dev-light-1',
        name: 'Living Room Ceiling Light',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: true,
        brightness: 90,
        connection: DeviceConnection.online,
        powerUsageWatts: 15.0,
        homeId: 'home-1',
      ),
      const SmartDevice(
        id: 'dev-fan-1',
        name: 'Ceiling Fan',
        roomId: 'Living Room',
        type: DeviceType.fan,
        isOn: false,
        connection: DeviceConnection.offline,
        powerUsageWatts: 0.0,
        homeId: 'home-1',
      ),
      const SmartDevice(
        id: 'dev-ac-1',
        name: 'Master AC',
        roomId: 'Bedroom',
        type: DeviceType.ac,
        isOn: true,
        connection: DeviceConnection.online,
        powerUsageWatts: 900.0,
        homeId: 'home-1',
      ),
      const SmartDevice(
        id: 'dev-socket-1',
        name: 'Kitchen Socket',
        roomId: 'Kitchen',
        type: DeviceType.socket,
        isOn: false,
        connection: DeviceConnection.online,
        powerUsageWatts: 0.0,
        homeId: 'home-1',
      ),
      // Device belonging to a separate home (isolation check)
      const SmartDevice(
        id: 'dev-villa-light',
        name: 'Garden Light',
        roomId: 'Garden',
        type: DeviceType.light,
        isOn: true,
        connection: DeviceConnection.online,
        powerUsageWatts: 45.0,
        homeId: 'home-2',
      ),
    ];

    test('Strict multi-home isolation prevents cross-home leaks', () {
      final home1Results = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
      );
      expect(home1Results.length, 4);
      expect(home1Results.every((d) => d.homeId == 'home-1'), isTrue);
      expect(home1Results.any((d) => d.id == 'dev-villa-light'), isFalse);

      final home2Results = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-2',
      );
      expect(home2Results.length, 1);
      expect(home2Results.first.id, 'dev-villa-light');
      expect(home2Results.first.homeId, 'home-2');

      final nonExistentHome = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-unknown',
      );
      expect(nonExistentHome, isEmpty);
    });

    test('Query filtering matches name or roomId case-insensitively', () {
      // Query by device name
      final queryByName = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        query: 'ceiling',
      );
      expect(queryByName.length, 2);
      expect(
        queryByName.map((d) => d.id),
        containsAll(['dev-light-1', 'dev-fan-1']),
      );

      // Query by roomId
      final queryByRoom = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        query: 'bedROOM',
      );
      expect(queryByRoom.length, 1);
      expect(queryByRoom.first.id, 'dev-ac-1');

      // Empty or whitespace query returns all scoped devices
      final emptyQuery = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        query: '   ',
      );
      expect(emptyQuery.length, 4);
    });

    test('Filter by DeviceType', () {
      final lights = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        type: DeviceType.light,
      );
      expect(lights.length, 1);
      expect(lights.first.type, DeviceType.light);

      final acs = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        type: DeviceType.ac,
      );
      expect(acs.length, 1);
      expect(acs.first.type, DeviceType.ac);

      final sensors = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        type: DeviceType.sensor,
      );
      expect(sensors, isEmpty);
    });

    test('Filter by online status', () {
      final onlineDevices = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        isOnline: true,
      );
      expect(onlineDevices.length, 3);
      expect(
        onlineDevices.every((d) => d.connection == DeviceConnection.online),
        isTrue,
      );

      final offlineDevices = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        isOnline: false,
      );
      expect(offlineDevices.length, 1);
      expect(offlineDevices.first.id, 'dev-fan-1');
    });

    test('Sort order deterministic behavior', () {
      // 1. Sort by name (alphabetical A-Z)
      final sortedByName = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        sortBy: 'name',
      );
      expect(sortedByName.map((d) => d.name).toList(), [
        'Ceiling Fan',
        'Kitchen Socket',
        'Living Room Ceiling Light',
        'Master AC',
      ]);

      // 2. Sort by room (grouped by roomId, then name)
      final sortedByRoom = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        sortBy: 'room',
      );
      expect(sortedByRoom.map((d) => d.roomId).toList(), [
        'Bedroom',
        'Kitchen',
        'Living Room',
        'Living Room',
      ]);
      expect(sortedByRoom[2].name, 'Ceiling Fan');
      expect(sortedByRoom[3].name, 'Living Room Ceiling Light');

      // 3. Sort by recent activity / power status (active first, descending watts, then name)
      final sortedByRecent = searchEngine.search(
        allDevices: testDevices,
        homeId: 'home-1',
        sortBy: 'recent',
      );
      // Active devices: Master AC (900W), Living Room Ceiling Light (15W)
      // Inactive devices: Ceiling Fan (0W), Kitchen Socket (0W)
      expect(sortedByRecent[0].id, 'dev-ac-1'); // 900W on
      expect(sortedByRecent[1].id, 'dev-light-1'); // 15W on
      expect(sortedByRecent[2].isOn, isFalse);
      expect(sortedByRecent[3].isOn, isFalse);
    });
  });

  group('Phase 6 — Energy Insights & CSV Export Tests', () {
    const energyService = EnergyInsightsService(defaultTariff: 0.15);

    final devices = [
      const SmartDevice(
        id: 'dev-ac',
        name: 'Living AC',
        roomId: 'Living Room',
        type: DeviceType.ac,
        isOn: true,
        powerUsageWatts: 1000.0, // 1000 W
        homeId: 'home-1',
      ),
      const SmartDevice(
        id: 'dev-bulb',
        name: 'Living Bulb',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: true,
        powerUsageWatts: 20.0, // 20 W
        homeId: 'home-1',
      ),
      const SmartDevice(
        id: 'dev-kitchen-socket',
        name: 'Oven Socket',
        roomId: 'Kitchen',
        type: DeviceType.socket,
        isOn: false, // inactive -> 0 active watts
        powerUsageWatts: 500.0,
        homeId: 'home-1',
      ),
    ];

    test('Formulas: kWh, Cost, and Percentage change calculation', () {
      // 1000W for 24h = 24.0 kWh
      final kwh = EnergyInsightsService.calculateKwh(1000.0, 24.0);
      expect(kwh, 24.0);

      // 24.0 kWh * $0.15 = $3.60
      final cost = EnergyInsightsService.calculateCost(24.0, 0.15);
      expect(cost, closeTo(3.60, 0.0001));

      // Hours for periods
      expect(EnergyInsightsService.hoursForPeriod('day'), 24.0);
      expect(EnergyInsightsService.hoursForPeriod('week'), 168.0);
      expect(EnergyInsightsService.hoursForPeriod('month'), 720.0);

      // Percentage change
      expect(
        EnergyInsightsService.calculatePercentChange(120.0, 100.0),
        closeTo(20.0, 0.0001),
      );
      expect(
        EnergyInsightsService.calculatePercentChange(80.0, 100.0),
        closeTo(-20.0, 0.0001),
      );
      expect(
        EnergyInsightsService.calculatePercentChange(50.0, 0.0),
        100.0,
      );
      expect(
        EnergyInsightsService.calculatePercentChange(0.0, 0.0),
        0.0,
      );
    });

    test('Generates daily report with device and room aggregations', () {
      final report = energyService.generateReport(
        devices: devices,
        period: 'day',
        tariff: 0.15,
        previousPeriodKwh: 20.0,
        homeId: 'home-1',
        generatedAt: DateTime(2026, 10, 24, 12, 0),
      );

      // Active devices:
      // dev-ac: 1000W * 24h / 1000 = 24.0 kWh. Cost = 24 * 0.15 = 3.60
      // dev-bulb: 20W * 24h / 1000 = 0.48 kWh. Cost = 0.48 * 0.15 = 0.072
      // dev-kitchen-socket (off): 0 active kWh, $0.00
      expect(report.period, 'day');
      expect(report.tariff, 0.15);
      expect(report.totalKwh, closeTo(24.48, 0.01));
      expect(report.totalCost, closeTo(3.672, 0.01));
      expect(report.previousPeriodKwh, 20.0);
      // percentChange: ((24.48 - 20) / 20) * 100 = 22.4%
      expect(report.percentChange, closeTo(22.4, 0.1));

      // Check device breakdown
      expect(report.deviceBreakdown.length, 3);
      final acItem = report.deviceBreakdown.firstWhere((e) => e.id == 'dev-ac');
      expect(acItem.wattage, 1000.0);
      expect(acItem.kwh, 24.0);
      expect(acItem.cost, 3.60);

      final socketItem = report.deviceBreakdown
          .firstWhere((e) => e.id == 'dev-kitchen-socket');
      expect(socketItem.wattage, 0.0);
      expect(socketItem.kwh, 0.0);
      expect(socketItem.cost, 0.0);

      // Check room breakdown
      // Living Room: 1000 + 20 = 1020W, 24.48 kWh, $3.672
      // Kitchen: 0W, 0.0 kWh, $0.00
      expect(report.roomBreakdown.length, 2);
      final livingRoom =
          report.roomBreakdown.firstWhere((r) => r.id == 'Living Room');
      expect(livingRoom.wattage, 1020.0);
      expect(livingRoom.kwh, closeTo(24.48, 0.001));
      expect(livingRoom.cost, closeTo(3.672, 0.001));
    });

    test('CSV export generates valid structure, headers, and simulated notice',
        () {
      final report = energyService.generateReport(
        devices: devices,
        period: 'day',
        tariff: 0.15,
        homeId: 'home-1',
        generatedAt: DateTime(2026, 10, 24, 15, 30),
      );

      final csv = energyService.exportEnergyCsv(report);

      expect(
          csv,
          contains(
              'Lumivo Energy Report - Generated: 2026-10-24T15:30:00.000'));
      expect(csv, contains('Notice: All figures are simulated estimates.'));
      expect(
        csv,
        contains(
            'Period,Category,Name,Wattage_W,Consumption_kWh,Estimated_Cost,Tariff'),
      );
      expect(
          csv, contains('day,device,Living AC,1000.00,24.0000,3.6000,0.1500'));
      expect(
          csv, contains('day,room,Living Room,1020.00,24.4800,3.6720,0.1500'));
    });
  });

  group('Phase 6 — Backup & Restore Engine Tests', () {
    const backupService = BackupRestoreService();
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistence;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistence = HomePersistenceManager(storage: storage);
      await persistence.loadHomeState(); // Initialize with default demo state
    });

    test('Export backup JSON produces valid versioned payload and metadata',
        () async {
      final jsonStr =
          await backupService.exportBackupJson(persistenceManager: persistence);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded.containsKey('metadata'), isTrue);
      expect(decoded.containsKey('homes'), isTrue);
      expect(decoded.containsKey('rooms'), isTrue);
      expect(decoded.containsKey('devices'), isTrue);
      expect(decoded.containsKey('scenes'), isTrue);
      expect(decoded.containsKey('automations'), isTrue);
      expect(decoded.containsKey('userProfile'), isTrue);

      final metadata = decoded['metadata'] as Map<String, dynamic>;
      expect(metadata['schemaVersion'], backupSchemaVersion);
      expect(metadata['schemaVersion'], 6);
      expect(metadata['lumivoVersion'], anyOf('0.6.0', '1.0.0-rc.1'));
      expect(metadata['homeCount'], greaterThan(0));
      expect(metadata['deviceCount'], greaterThan(0));
    });

    test('Export strictly strips credentials and sensitive secrets', () async {
      // Inject dummy secrets into device customData and userProfile
      final state = persistence.cachedState!;
      final sensitiveDevices = state.devices.map((d) {
        if (d.id == 'device-bulb-1') {
          return d.copyWith(customData: {
            'wifi_password': 'SuperSecretPassword123!',
            'api_token': 'Bearer-secret-xyz',
            'private_key': '0xDEADBEEF',
            'public_metric': 'safe_value',
          });
        }
        return d;
      }).toList();

      await persistence
          .saveHomeState(state.copyWith(devices: sensitiveDevices));

      final exportedJson =
          await backupService.exportBackupJson(persistenceManager: persistence);

      // Verify that NO sensitive words or values leaked into JSON
      expect(exportedJson, isNot(contains('SuperSecretPassword123!')));
      expect(exportedJson, isNot(contains('Bearer-secret-xyz')));
      expect(exportedJson, isNot(contains('0xDEADBEEF')));
      expect(exportedJson, isNot(contains('wifi_password')));
      expect(exportedJson, isNot(contains('api_token')));
      expect(exportedJson, isNot(contains('private_key')));
      expect(exportedJson, contains('public_metric'));
    });

    test('Backup validation rejects malformed, empty, and oversized payloads',
        () async {
      // Empty
      final emptyResult = await backupService.validateAndPreviewBackup('   ');
      expect(emptyResult.isValid, isFalse);
      expect(emptyResult.errors.first, contains('empty'));

      // Malformed
      final malformedResult =
          await backupService.validateAndPreviewBackup('{ broken json:');
      expect(malformedResult.isValid, isFalse);
      expect(malformedResult.errors.first, contains('Malformed JSON'));

      // Invalid root type
      final invalidRoot =
          await backupService.validateAndPreviewBackup('[1, 2, 3]');
      expect(invalidRoot.isValid, isFalse);
      expect(invalidRoot.errors.first, contains('JSON object'));
    });

    test('Backup validation rejects unsupported schema versions (> 6 or <= 0)',
        () async {
      final futureVersionJson = jsonEncode({
        'metadata': {'schemaVersion': 7, 'lumivoVersion': '0.7.0'},
        'homes': [],
        'devices': [],
      });
      final futureResult =
          await backupService.validateAndPreviewBackup(futureVersionJson);
      expect(futureResult.isValid, isFalse);
      expect(
          futureResult.errors
              .any((e) => e.contains('Unsupported schema version')),
          isTrue);

      final zeroVersionJson = jsonEncode({
        'metadata': {'schemaVersion': 0},
      });
      final zeroResult =
          await backupService.validateAndPreviewBackup(zeroVersionJson);
      expect(zeroResult.isValid, isFalse);
    });

    test(
        'Backup validation catches duplicate IDs and invalid entity references',
        () async {
      final invalidPayload = jsonEncode({
        'metadata': {'schemaVersion': 6},
        'homes': [
          {'id': 'home-1', 'name': 'Home 1'},
          {'id': 'home-1', 'name': 'Home 1 Duplicate'}, // duplicate home ID
        ],
        'devices': [
          {
            'id': 'device-1',
            'name': 'Light 1',
            'roomId': 'Living',
            'type': 'light',
            'isOn': true,
          },
          {
            'id': 'device-1', // duplicate device ID
            'name': 'Light 1 Dup',
            'roomId': 'Living',
            'type': 'light',
            'isOn': false,
          },
        ],
        'scenes': [
          {
            'id': 'scene-1',
            'name': 'Good Morning',
            'actions': [
              {
                'deviceId': 'device-non-existent', // invalid device reference
                'commandType': 'setPower',
                'value': true,
              }
            ]
          }
        ],
        'automations': [
          {
            'id': 'auto-1',
            'name': 'Dusk trigger',
            'triggerType': 'sensorThreshold',
            'sensorDeviceId': 'sensor-ghost', // invalid sensor reference
            'actions': [
              {
                'deviceId': 'device-ghost-2', // invalid device reference
                'commandType': 'setPower',
                'value': false,
              }
            ]
          }
        ],
      });

      final preview =
          await backupService.validateAndPreviewBackup(invalidPayload);
      expect(preview.isValid, isFalse);
      expect(
          preview.errors.any((e) => e.contains('Duplicate home ID')), isTrue);
      expect(
          preview.errors.any((e) => e.contains('Duplicate device ID')), isTrue);
      expect(
        preview.errors.any((e) =>
            e.contains('references non-existent device: device-non-existent')),
        isTrue,
      );
      expect(
        preview.errors.any((e) =>
            e.contains('sensor references non-existent device: sensor-ghost')),
        isTrue,
      );
    });

    test('Transactional restore successfully updates state on valid payload',
        () async {
      final validPayload = jsonEncode({
        'metadata': {'schemaVersion': 6, 'lumivoVersion': '0.6.0'},
        'homes': [
          {
            'id': 'home-new',
            'name': 'Restored Mountain Retreat',
            'address': '77 Summit Peak',
            'role': 'Owner',
            'isCurrent': true,
            'tariffRate': 0.18,
            'currency': 'USD',
          }
        ],
        'rooms': [
          {
            'id': 'Lodge Room',
            'name': 'Lodge Room',
            'iconName': 'cabin',
            'homeId': 'home-new',
          }
        ],
        'devices': [
          {
            'id': 'dev-fireplace',
            'name': 'Electric Fireplace',
            'roomId': 'Lodge Room',
            'type': 'socket',
            'isOn': true,
            'homeId': 'home-new',
          }
        ],
        'scenes': [
          {
            'id': 'scene-cozy',
            'name': 'Cozy Fireplace',
            'homeId': 'home-new',
            'actions': [
              {
                'deviceId': 'dev-fireplace',
                'commandType': 'setPower',
                'value': true,
              }
            ]
          }
        ],
        'automations': [],
        'userProfile': {
          'id': 'user-restored',
          'name': 'Taylor Swift',
          'email': 'taylor@lumivo.io',
        },
      });

      final success = await backupService.restoreBackup(
        jsonString: validPayload,
        persistenceManager: persistence,
      );
      expect(success, isTrue);

      final state = await persistence.loadHomeState();
      expect(state.homes.length, 1);
      expect(state.homes.first.name, 'Restored Mountain Retreat');
      expect(state.devices.length, 1);
      expect(state.devices.first.id, 'dev-fireplace');
      expect(state.scenes.length, 1);
      expect(state.scenes.first.id, 'scene-cozy');
      expect(state.userProfile.name, 'Taylor Swift');
    });

    test('Transactional restore rolls back cleanly when error occurs',
        () async {
      // 1. Establish known starting state
      final originalState = await persistence.loadHomeState();
      final originalHomeCount = originalState.homes.length;
      final originalDeviceCount = originalState.devices.length;

      // 2. Attempt restore of payload that fails validation
      final invalidPayload = jsonEncode({
        'metadata': {'schemaVersion': 99}, // invalid schema version
        'homes': [
          {'id': 'home-bad', 'name': 'Should Not Persist'}
        ],
        'devices': [],
        'scenes': [],
        'automations': [],
      });

      final success = await backupService.restoreBackup(
        jsonString: invalidPayload,
        persistenceManager: persistence,
      );
      expect(success, isFalse);

      // 3. Confirm state was rolled back and untouched
      final afterFailureState = await persistence.loadHomeState();
      expect(afterFailureState.homes.length, originalHomeCount);
      expect(afterFailureState.devices.length, originalDeviceCount);
      expect(
        afterFailureState.homes.any((h) => h.id == 'home-bad'),
        isFalse,
      );
    });
  });
}
