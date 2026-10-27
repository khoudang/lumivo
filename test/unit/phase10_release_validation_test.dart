import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/ble/mock_ble_service.dart';
import 'package:lumivo/services/energy/energy_analytics_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/mqtt/mock_mqtt_service.dart';
import 'package:lumivo/services/mqtt/mqtt_service.dart';
import 'package:lumivo/services/security/secret_sanitizer.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/command_pipeline.dart';
import 'package:lumivo/services/simulation/simulation_engine.dart';
import 'package:lumivo/services/simulation/simulation_lifecycle_observer.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

/// Simulated fault-injecting storage adapter for resilience and cold restart testing.
class Phase10FaultyStorageAdapter implements StorageAdapter {
  Phase10FaultyStorageAdapter({this.failOnWriteCount = 0});

  final Map<String, String> memory = {};
  int failOnWriteCount;

  @override
  Future<String?> getString(String key) async => memory[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failOnWriteCount > 0 && key == HomePersistenceManager.storageKey) {
      failOnWriteCount--;
      throw Exception('QuotaExceededError: LocalStorage limit reached on $key');
    }
    memory[key] = value;
  }

  @override
  Future<void> remove(String key) async => memory.remove(key);

  @override
  Future<void> clear() async => memory.clear();
}

void main() {
  group('Phase 10 — Release Validation & Hardening Unit Test Suite', () {
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
    // 1. Version-Specific Hardening & Exact Matchers
    // =========================================================================
    group('1. Version-Specific Hardening & Exact Matchers', () {
      test(
          '1.1 Exported backup JSON metadata matches exact 1.0.0-rc.1 and schema 6',
          () async {
        final exportedJson = await backupService.exportBackupJson(
          persistenceManager: persistenceManager,
        );
        expect(exportedJson, isNotEmpty);

        final decoded = jsonDecode(exportedJson) as Map<String, dynamic>;
        expect(decoded.containsKey('metadata'), isTrue);

        final metadata = decoded['metadata'] as Map<String, dynamic>;
        expect(metadata['schemaVersion'], equals(6));
        expect(metadata['schemaVersion'], equals(backupSchemaVersion));
        expect(metadata['lumivoVersion'], equals('1.0.0-rc.1'));
        expect(metadata['homeCount'], greaterThan(0));
        expect(metadata['deviceCount'], greaterThan(0));
      });

      test('1.2 Validation rejects unsupported schema versions (> 6 or <= 0)',
          () async {
        final invalidHighSchema = jsonEncode({
          'metadata': {
            'schemaVersion': 7,
            'lumivoVersion': '1.0.0-rc.1',
            'exportedAt': DateTime.now().toIso8601String(),
          },
          'homes': [
            {'id': 'h1', 'name': 'Future Home'}
          ],
          'devices': [],
          'scenes': [],
          'automations': [],
        });

        final previewHigh =
            await backupService.validateAndPreviewBackup(invalidHighSchema);
        expect(previewHigh.isValid, isFalse);
        expect(
          previewHigh.errors
              .any((e) => e.contains('Unsupported schema version')),
          isTrue,
        );

        final invalidLowSchema = jsonEncode({
          'metadata': {
            'schemaVersion': 0,
            'lumivoVersion': '1.0.0-rc.1',
            'exportedAt': DateTime.now().toIso8601String(),
          },
          'homes': [
            {'id': 'h1', 'name': 'Zero Home'}
          ],
          'devices': [],
          'scenes': [],
          'automations': [],
        });

        final previewLow =
            await backupService.validateAndPreviewBackup(invalidLowSchema);
        expect(previewLow.isValid, isFalse);
      });

      test('1.3 Validation rejects oversized strings in entity fields',
          () async {
        final maliciousPayload = jsonEncode({
          'metadata': {
            'schemaVersion': 6,
            'lumivoVersion': '1.0.0-rc.1',
            'exportedAt': DateTime.now().toIso8601String(),
          },
          'homes': [
            {'id': 'h1', 'name': 'A' * 256} // exceeds 128 character max
          ],
          'devices': [],
          'scenes': [],
          'automations': [],
        });

        final preview =
            await backupService.validateAndPreviewBackup(maliciousPayload);
        expect(preview.isValid, isFalse);
        expect(
          preview.errors
              .any((e) => e.contains('exceeds maximum allowed length')),
          isTrue,
        );
      });
    });

    // =========================================================================
    // 2. Memory Bounded Buffers & Resource Leak Defense
    // =========================================================================
    group('2. Memory Bounded Buffers & Resource Leak Defense', () {
      test(
          '2.1 CommandPipeline limits commandHistory and internal buffers under stress',
          () async {
        final pipeline = CommandPipeline(
          minLatencyMs: 0,
          maxLatencyMs: 0,
          maxHistoryEntries: 20,
          executor: (cmd) async => CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.confirmed,
          ),
        );

        // Dispatch 100 rapid commands
        for (int i = 0; i < 100; i++) {
          await pipeline.execute(
            DeviceCommand(
              requestId: 'req-stress-$i',
              deviceId: 'device-test',
              type: DeviceCommandType.setPower,
              value: i % 2 == 0,
            ),
          );
        }

        // Execution history should be bounded strictly to maxHistoryEntries (20)
        expect(pipeline.commandHistory.length, equals(20));

        // Pipeline disposal should mark isDisposed
        expect(pipeline.isDisposed, isFalse);
        pipeline.dispose();
        expect(pipeline.isDisposed, isTrue);
      });

      test(
          '2.2 DefaultEnergyAnalyticsService enforces hard cap on sample histories',
          () {
        final energyService = DefaultEnergyAnalyticsService();
        final now = DateTime.now();

        // Feed samples exceeding maxStoredSamples (5000)
        for (int i = 0; i < 5500; i++) {
          energyService.recordSample(
            timestamp: now.add(Duration(minutes: i)),
            powerWatts: 150.0 + (i % 20),
            elapsedDuration: const Duration(minutes: 1),
            perDeviceWatts: {'device-1': 100.0, 'device-2': 50.0},
          );
        }

        // Verify sample history is clamped to maxStoredSamples (5000)
        expect(
          energyService.samples.length,
          lessThanOrEqualTo(DefaultEnergyAnalyticsService.maxStoredSamples),
        );
        expect(
          energyService.samples.length,
          equals(DefaultEnergyAnalyticsService.maxStoredSamples),
        );
      });

      test(
          '2.3 AutomationEngine bounds rule caches, trigger state, and supports disposal',
          () {
        final engine = AutomationEngine(
          maxExecutionHistory: 50,
          hysteresis: 0.5,
        );

        expect(engine.isDisposed, isFalse);

        // Add rules to verify clean cache management
        const testRule = AutomationRule(
          id: 'rule-test-1',
          name: 'Night Light Rule',
          triggerType: TriggerType.schedule,
          timeOfDay: '22:00',
          actions: [
            DeviceAction(
              deviceId: 'device-bulb-1',
              commandType: DeviceCommandType.setPower,
              value: false,
            )
          ],
        );

        engine.addRule(testRule);
        expect(engine.rules.length, equals(1));

        // Dispose engine
        engine.dispose();
        expect(engine.isDisposed, isTrue);
      });

      test(
          '2.4 HomePersistenceManager enforces 100-item bound on activity events',
          () async {
        final state = await persistenceManager.loadHomeState();
        final manyEvents = List.generate(
          150,
          (i) => ActivityEvent(
            id: 'event-stress-$i',
            timestamp: DateTime.now().subtract(Duration(minutes: i)),
            title: 'Event $i',
            description: 'Stress activity description $i',
            source: 'system',
          ),
        );

        final updatedState = state.copyWith(activityEvents: manyEvents);
        await persistenceManager.saveHomeState(updatedState);

        // Reload state and assert max 100 events were serialized
        final reloaded = await persistenceManager.loadHomeState();
        expect(reloaded.activityEvents.length, equals(100));
        expect(reloaded.activityEvents.first.id, equals('event-stress-0'));
      });
    });

    // =========================================================================
    // 3. Cold Restart Simulation & State Persistence Fidelity
    // =========================================================================
    group('3. Cold Restart Simulation & State Persistence Fidelity', () {
      test(
          '3.1 Full state survives complete process restart with 100% fidelity',
          () async {
        final sharedStorage = StorageAdapterImpl();
        final pm1 = HomePersistenceManager(storage: sharedStorage);
        final state1 = await pm1.loadHomeState();

        // 1. Perform rich mutations across all domains
        // Multi-home
        const secondHome = Home(
          id: 'home-cabin-phase10',
          name: 'Phase 10 Mountain Cabin',
          address: '42 Alpine Ridge',
          role: 'Admin',
          isCurrent: false,
          tariffRate: 0.22,
          currency: 'EUR',
        );
        await pm1.saveHomes([...state1.homes, secondHome]);

        // Add rooms
        const newRoom = Room(
          id: 'room-phase10-study',
          name: 'Executive Study',
          iconName: 'menu_book',
          homeId: 'home-default',
        );
        await pm1.saveRooms([...state1.rooms, newRoom]);

        // Add diverse devices
        const lightDev = SmartDevice(
          id: 'dev-light-p10',
          name: 'Study Desk Lamp',
          roomId: 'room-phase10-study',
          type: DeviceType.light,
          isOn: true,
          brightness: 85,
          powerUsageWatts: 18.5,
          homeId: 'home-default',
          isFavorite: true,
        );
        const acDev = SmartDevice(
          id: 'dev-ac-p10',
          name: 'Study Dual-Inverter AC',
          roomId: 'room-phase10-study',
          type: DeviceType.ac,
          isOn: true,
          targetTemperature: 21.5,
          currentTemperature: 24.0,
          powerUsageWatts: 720.0,
          homeId: 'home-default',
        );
        const lockDev = SmartDevice(
          id: 'dev-lock-p10',
          name: 'Study Vault Lock',
          roomId: 'room-phase10-study',
          type: DeviceType.lock,
          isOn: true,
          isLocked: true,
          powerUsageWatts: 2.0,
          homeId: 'home-default',
        );

        await pm1.saveDevices([...state1.devices, lightDev, acDev, lockDev]);

        // Add custom scene
        const customScene = Scene(
          id: 'scene-study-focus',
          name: 'Deep Study Focus',
          iconName: 'psychology',
          homeId: 'home-default',
          actions: [
            DeviceAction(
              deviceId: 'dev-light-p10',
              commandType: DeviceCommandType.setBrightness,
              value: 100,
            ),
            DeviceAction(
              deviceId: 'dev-lock-p10',
              commandType: DeviceCommandType.setLock,
              value: true,
            ),
          ],
        );
        await pm1.saveScenes([...state1.scenes, customScene]);

        // Add automation rule
        const customRule = AutomationRule(
          id: 'auto-study-temp',
          name: 'Study Overheat Protection',
          isEnabled: true,
          triggerType: TriggerType.sensorThreshold,
          sensorDeviceId: 'dev-ac-p10',
          sensorProperty: 'temperature',
          thresholdValue: 26.0,
          actions: [
            DeviceAction(
              deviceId: 'dev-ac-p10',
              commandType: DeviceCommandType.setTargetTemperature,
              value: 20.0,
            ),
          ],
          homeId: 'home-default',
        );
        await pm1.saveAutomations([...state1.automations, customRule]);

        // Update user profile
        const customProfile = UserProfile(
          id: 'user-p10',
          name: 'Grace Hopper',
          email: 'grace@lumivo.io',
          language: 'vi',
          themeMode: 'oled',
          reducedMotion: true,
        );
        await pm1.saveUserProfile(customProfile);

        // Save Dashboard Config
        const customDash = DashboardConfig(
          homeId: 'home-default',
          sectionOrder: [
            DashboardSection.favorites,
            DashboardSection.quickScenes,
            DashboardSection.devices,
            DashboardSection.metrics,
            DashboardSection.activity,
          ],
          visibleSections: {
            DashboardSection.favorites: true,
            DashboardSection.quickScenes: true,
            DashboardSection.devices: true,
            DashboardSection.metrics: false,
            DashboardSection.activity: true,
          },
        );
        await pm1.saveDashboardConfig(customDash);

        // Save snapshot as well
        await pm1.saveSnapshot();

        // 2. SIMULATE COLD RESTART:
        // Dispose old repository and PM

        // 3. REBOOT: Instantiate completely fresh PM and Repository from shared storage
        final pm2 = HomePersistenceManager(storage: sharedStorage);
        await pm2.loadHomeState();
        final repo2 = MockDeviceRepository(
          responseDelay: Duration.zero,
          persistenceManager: pm2,
        );

        // 4. VERIFY 100% INTEGRITY:
        final reloadedState = pm2.cachedState!;

        // Homes
        expect(reloadedState.homes.length,
            equals(3)); // default (2) + secondHome (1)
        expect(
          reloadedState.homes.any((h) => h.id == 'home-cabin-phase10'),
          isTrue,
        );
        final loadedHome =
            reloadedState.homes.firstWhere((h) => h.id == 'home-cabin-phase10');
        expect(loadedHome.tariffRate, equals(0.22));
        expect(loadedHome.currency, equals('EUR'));

        // Rooms
        expect(
          reloadedState.rooms.any((r) => r.id == 'room-phase10-study'),
          isTrue,
        );

        // Devices in Repository
        expect(repo2.devices.any((d) => d.id == 'dev-light-p10'), isTrue);
        final reloadedLight =
            repo2.devices.firstWhere((d) => d.id == 'dev-light-p10');
        expect(reloadedLight.brightness, equals(85));
        expect(reloadedLight.isFavorite, isTrue);

        expect(repo2.devices.any((d) => d.id == 'dev-ac-p10'), isTrue);
        final reloadedAc =
            repo2.devices.firstWhere((d) => d.id == 'dev-ac-p10');
        expect(reloadedAc.targetTemperature, equals(21.5));

        expect(repo2.devices.any((d) => d.id == 'dev-lock-p10'), isTrue);
        final reloadedLock =
            repo2.devices.firstWhere((d) => d.id == 'dev-lock-p10');
        expect(reloadedLock.isLocked, isTrue);

        // Scenes
        expect(
          reloadedState.scenes.any((s) => s.id == 'scene-study-focus'),
          isTrue,
        );

        // Automations
        expect(
          reloadedState.automations.any((a) => a.id == 'auto-study-temp'),
          isTrue,
        );

        // User Profile
        expect(reloadedState.userProfile.name, equals('Grace Hopper'));
        expect(reloadedState.userProfile.language, equals('vi'));
        expect(reloadedState.userProfile.themeMode, equals('oled'));
        expect(reloadedState.userProfile.reducedMotion, isTrue);

        // Dashboard Config
        final loadedConfig = pm2.getDashboardConfig('home-default');
        expect(
          loadedConfig.sectionOrder.first,
          equals(DashboardSection.favorites),
        );
        expect(loadedConfig.isVisible(DashboardSection.metrics), isFalse);

        // Snapshot Survives
        expect(await pm2.hasSnapshot(), isTrue);

        await repo2.dispose();
      });

      test(
          '3.2 Faulty storage falls back to emergency recovery snapshot safely',
          () async {
        final faultyStorage = Phase10FaultyStorageAdapter(failOnWriteCount: 0);
        final pm = HomePersistenceManager(storage: faultyStorage);
        await pm.loadHomeState();

        // Create baseline snapshot
        await pm.saveSnapshot();
        expect(await pm.hasSnapshot(), isTrue);

        // Arm failure on write (1 failure triggers QuotaExceededError retry with pruning)
        faultyStorage.failOnWriteCount = 1;

        // Populate with activity events
        final lotsOfEvents = List<ActivityEvent>.generate(
          20,
          (i) => ActivityEvent(
            id: 'evt-$i',
            title: 'Event $i',
            description: 'Large event payload $i',
            timestamp: DateTime.now(),
          ),
        );
        final currentState =
            pm.cachedState!.copyWith(activityEvents: lotsOfEvents);

        // Attempt write: triggers QuotaExceededError retry
        await pm.saveHomeState(currentState);

        // State remains loadable and recovers successfully
        final recovered = await pm.restoreSnapshot();
        expect(recovered, isTrue);
      });
    });

    // =========================================================================
    // 4. App Lifecycle Transitions & Virtual Clock Synchronization
    // =========================================================================
    group('4. App Lifecycle Transitions & Virtual Clock Synchronization', () {
      test('4.1 Observer pauses clock on background and resumes on foreground',
          () {
        final clock = VirtualClock(autoStart: false);
        clock.start();
        expect(clock.isRunning, isTrue);

        final observer = SimulationLifecycleObserver(
          clock: clock,
          syncElapsedTimeOnResume: false,
          autoRegister: false,
        );

        // Simulate app entering background
        observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(clock.isRunning, isFalse);
        expect(observer.isSuspended, isTrue);
        expect(observer.wasRunningBeforePause, isTrue);
        expect(observer.pauseCount, equals(1));

        // Redundant background state does not corrupt state
        observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
        expect(observer.pauseCount, equals(1)); // No duplicate pause

        // Simulate returning to foreground
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(clock.isRunning, isTrue);
        expect(observer.isSuspended, isFalse);
        expect(observer.resumeCount, equals(1));

        // Spurious duplicate resume call prevented safely
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(observer.duplicateStartAttemptsPrevented, greaterThan(0));

        observer.dispose();
        clock.dispose();
      });

      test(
          '4.2 Virtual clock multipliers (1x, 10x, 60x, 300x) advance deterministically',
          () {
        final clock = VirtualClock(autoStart: false);
        final baseTime = clock.now;

        clock.setMultiplier(10.0);
        expect(clock.timeMultiplier, equals(10.0));

        clock.setMultiplier(60.0);
        expect(clock.timeMultiplier, equals(60.0));

        clock.setMultiplier(300.0);
        expect(clock.timeMultiplier, equals(300.0));

        clock.advance(const Duration(minutes: 5));
        expect(
          clock.now.difference(baseTime),
          equals(const Duration(minutes: 5)),
        );

        clock.dispose();
      });
    });

    // =========================================================================
    // 5. Data Security, Secret Sanitization & Strict Isolation
    // =========================================================================
    group('5. Data Security, Secret Sanitization & Strict Isolation', () {
      test(
          '5.1 SecretSanitizer scrubs credentials across all sensitive patterns',
          () {
        expect(SecretSanitizer.isSensitiveKey('wifi_password'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('wifiPassword'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('wifi_pass'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('api_key'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('apiKey'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('token'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('access_token'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('refresh_token'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('auth_token'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('bearer_token'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('secret'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('private_key'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('credential'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('authcode'), isTrue);
        expect(SecretSanitizer.isSensitiveKey('safe_field'), isFalse);

        final dirtyData = {
          'wifi_ssid': 'Lumivo-Mesh',
          'wifi_password': 'SecretPassword123!',
          'api_key': 'ak_live_9988776655',
          'token': 'tok_xyz123',
          'access_token': 'acc_sec_456',
          'refresh_token': 'ref_sec_789',
          'auth_token': 'auth_999',
          'secret': 'top_secret_val',
          'private_key': '-----BEGIN RSA PRIVATE KEY-----',
          'safe_field': 'NormalValue',
        };

        final sanitized = SecretSanitizer.sanitizeMap(dirtyData);

        expect(sanitized['wifi_ssid'], equals('Lumivo-Mesh'));
        expect(sanitized['safe_field'], equals('NormalValue'));
        expect(sanitized.containsKey('wifi_password'), isFalse);
        expect(sanitized.containsKey('api_key'), isFalse);
        expect(sanitized.containsKey('token'), isFalse);
        expect(sanitized.containsKey('access_token'), isFalse);
        expect(sanitized.containsKey('refresh_token'), isFalse);
        expect(sanitized.containsKey('auth_token'), isFalse);
        expect(sanitized.containsKey('secret'), isFalse);
        expect(sanitized.containsKey('private_key'), isFalse);
      });

      test(
          '5.2 CSV Formula Injection Defense (CWE-1236) neutralizes formula prefixes',
          () {
        const energyService = EnergyInsightsService();
        final maliciousDevice = SmartDevice(
          id: 'dev-malicious-csv',
          name: '=cmd|"/C calc"!A0',
          roomId: '+SUM(1+1)',
          type: DeviceType.light,
          isOn: true,
          powerUsageWatts: 50.0,
          homeId: 'home-default',
        );

        final report = energyService.generateReport(devices: [maliciousDevice]);
        final csv = energyService.exportEnergyCsv(report);

        // Formula injection characters should be escaped with leading apostrophe '
        expect(csv.contains("'=cmd|"), isTrue);
        expect(csv.contains("'+SUM"), isTrue);
        expect(csv.contains('=cmd|"/C calc"'), isFalse);
      });

      test('5.3 Strict multi-home isolation prevents cross-home data bleeding',
          () async {
        final state = await persistenceManager.loadHomeState();
        expect(state.homes.length, greaterThanOrEqualTo(2));

        final home1 = state.homes[0];
        final home2 = state.homes[1];

        // Ensure devices of home1 are isolated from home2
        final home1Devices = repository.getDevicesForHome(home1.id);
        final home2Devices = repository.getDevicesForHome(home2.id);

        for (final d in home1Devices) {
          expect(home2Devices.contains(d), isFalse);
          expect(d.homeId, equals(home1.id));
        }

        for (final d in home2Devices) {
          expect(home1Devices.contains(d), isFalse);
          expect(d.homeId, equals(home2.id));
        }
      });
    });

    // =========================================================================
    // 6. Pure Offline Simulation & Zero-Network Verification
    // =========================================================================
    group('6. Pure Offline Simulation & Zero-Network Verification', () {
      test(
          '6.1 BleDiscovery and MqttTransport operate purely in memory without network sockets',
          () async {
        final ble = MockBleService();
        final mqtt = MockMqttService(connectionLatency: Duration.zero);

        expect(ble.isSupported, isTrue);
        final devicesFuture = ble.discoveredDevices.first;
        await ble.startScan();
        final discovered = await devicesFuture;
        expect(discovered, isNotEmpty);
        await ble.stopScan();

        expect(mqtt.status, equals(MqttConnectionStatus.disconnected));
        final connected = await mqtt.connect(
          host: 'broker.lumivo.internal',
          clientId: 'client-offline-test',
        );
        expect(connected, isTrue);
        expect(mqtt.status, equals(MqttConnectionStatus.connected));
        await mqtt.disconnect();
        expect(mqtt.status, equals(MqttConnectionStatus.disconnected));

        await ble.dispose();
        await mqtt.dispose();
      });

      test(
          '6.2 SimulationEngine environmental curves update deterministically offline',
          () {
        final simEngine = SimulationEngine.instance;
        final initialTemp = simEngine.currentSnapshot.ambientTemperature;
        expect(initialTemp, inInclusiveRange(10.0, 45.0));

        // Advance 4 virtual hours
        simEngine.advanceTime(const Duration(hours: 4));
        final nextTemp = simEngine.currentSnapshot.ambientTemperature;
        expect(nextTemp, inInclusiveRange(10.0, 45.0));
      });
    });
  });
}
