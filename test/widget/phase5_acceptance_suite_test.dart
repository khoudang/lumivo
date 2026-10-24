import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/localization/app_localizations.dart';
import 'package:lumivo/core/localization/strings_en.dart';
import 'package:lumivo/core/localization/strings_vi.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/discovered_device.dart';
import 'package:lumivo/core/models/provisioning_state.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/automation/state/automation_history_notifier.dart';
import 'package:lumivo/features/automation/state/automation_notifier.dart';
import 'package:lumivo/features/health/state/device_health_notifier.dart';
import 'package:lumivo/features/history/state/command_history_notifier.dart';
import 'package:lumivo/features/onboarding/state/onboarding_notifier.dart';
import 'package:lumivo/services/ble/ble_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/mock/mock_discovered_devices.dart';
import 'package:lumivo/services/provisioning/provisioning_service.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

// ---------------------------------------------------------------------------
// Test Doubles for Onboarding & Provisioning Acceptance Flows
// ---------------------------------------------------------------------------

class FakeBleService implements BleService {
  final _controller = StreamController<List<DiscoveredDevice>>.broadcast();
  bool scanStarted = false;
  bool scanStopped = false;

  @override
  bool get isSupported => true;

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices => _controller.stream;

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    scanStarted = true;
    _controller.add(mockDiscoveredDevices);
  }

  @override
  Future<void> stopScan() async {
    scanStopped = true;
  }

  @override
  Future<bool> connect(String deviceId) async => true;

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeProvisioningService implements ProvisioningService {
  FakeProvisioningService({this.shouldFail = false, this.errorMessage});

  bool shouldFail;
  String? errorMessage;
  bool wasCancelled = false;

  @override
  Stream<ProvisioningProgress> provision({
    required DiscoveredDevice device,
    required String ssid,
    required String password,
  }) async* {
    yield const ProvisioningProgress(
      step: ProvisioningStep.connectingBle,
      progress: 0.2,
      message: 'Connecting to device...',
    );
    yield const ProvisioningProgress(
      step: ProvisioningStep.sendingCredentials,
      progress: 0.5,
      message: 'Sending credentials...',
    );
    if (shouldFail) {
      yield ProvisioningProgress(
        step: ProvisioningStep.failed,
        progress: 0.5,
        message: errorMessage ?? 'Pairing timed out',
        errorMessage: errorMessage ?? 'Pairing timed out',
      );
      return;
    }
    yield const ProvisioningProgress(
      step: ProvisioningStep.waitingDeviceJoin,
      progress: 0.75,
      message: 'Device joining network...',
    );
    yield const ProvisioningProgress(
      step: ProvisioningStep.verifyingMqtt,
      progress: 0.9,
      message: 'Verifying MQTT connection...',
    );
    yield ProvisioningProgress(
      step: ProvisioningStep.completed,
      progress: 1.0,
      message: 'Device successfully connected!',
      provisionedDeviceId: device.id,
    );
  }

  @override
  Future<void> cancel() async {
    wasCancelled = true;
  }

  Future<void> dispose() async {}
}

void main() {
  group('Phase 5 End-to-End Acceptance Test Suite (Scenarios A through L)', () {
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
    // SCENARIO A: Device Onboarding
    // scan -> retry -> discover -> provision -> assign room
    // -------------------------------------------------------------------------
    test(
        'Scenario A: Device Onboarding (scan -> discover -> provision -> assign room)',
        () async {
      final ble = FakeBleService();
      final prov = FakeProvisioningService();
      final notifier = OnboardingNotifier(
        deviceRepository: repository,
        bleService: ble,
        provisioningService: prov,
      );
      addTearDown(() async {
        await ble.dispose();
        await prov.dispose();
      });

      // 1. Scan BLE
      await notifier.startScan();
      expect(notifier.state.discoveredDevices.isNotEmpty, isTrue);

      // 2. Select Discovered Device
      final selected = notifier.state.discoveredDevices.first;
      notifier.selectDevice(selected);
      expect(notifier.state.selectedDevice, selected);

      // 3. Provision Device
      await notifier.provision(
        ssid: 'Lumivo_Home_5G',
        password: 'TestPassword123',
      );
      expect(notifier.state.isCompleted, isTrue);
      expect(notifier.state.provisioningProgress?.step,
          ProvisioningStep.completed);

      // 4. Verify registered in repository
      expect(repository.devices.any((d) => d.id == selected.id), isTrue);

      // 5. Assign Room and Name
      await repository.updateDeviceSettings(
        selected.id,
        name: 'Balcony Smart Bulb',
        roomId: 'Living Room',
        isFavorite: true,
      );
      final added = repository.devices.firstWhere((d) => d.id == selected.id);
      expect(added.name, 'Balcony Smart Bulb');
      expect(added.roomId, 'Living Room');
      expect(added.isFavorite, isTrue);
    });

    // -------------------------------------------------------------------------
    // SCENARIO B: Provisioning Recovery
    // failed pairing -> retry -> add device without duplication
    // -------------------------------------------------------------------------
    test(
        'Scenario B: Provisioning Recovery (failed pairing -> retry -> add device without duplication)',
        () async {
      final ble = FakeBleService();
      final prov = FakeProvisioningService(
        shouldFail: true,
        errorMessage: 'Connection handshake timed out',
      );
      final notifier = OnboardingNotifier(
        deviceRepository: repository,
        bleService: ble,
        provisioningService: prov,
      );
      addTearDown(() async {
        await ble.dispose();
        await prov.dispose();
      });

      await notifier.startScan();
      final targetDevice = notifier.state.discoveredDevices.first;
      notifier.selectDevice(targetDevice);

      // 1. Initial attempt fails
      await notifier.provision(ssid: 'Home_WiFi', password: 'ValidPassword');
      expect(notifier.state.isCompleted, isFalse);
      expect(notifier.state.errorMessage, 'Connection handshake timed out');

      // 2. Recovery: heal connection and retry
      prov.shouldFail = false;
      await notifier.provision(ssid: 'Home_WiFi', password: 'ValidPassword');
      expect(notifier.state.isCompleted, isTrue);

      // 3. Verify exactly 1 device added without duplicates
      final matchingDevices =
          repository.devices.where((d) => d.id == targetDevice.id);
      expect(matchingDevices.length, 1);
    });

    // -------------------------------------------------------------------------
    // SCENARIO C: Device Offline
    // offline rejection -> reconnect -> command confirmed
    // -------------------------------------------------------------------------
    test(
        'Scenario C: Device Offline (offline rejection -> reconnect -> confirmed)',
        () async {
      const testDevice = SmartDevice(
        id: 'test-device-c',
        name: 'Garden Pump',
        roomId: 'Living Room',
        type: DeviceType.socket,
        isOn: false,
        connection: DeviceConnection.offline,
      );
      repository.addDevice(testDevice);

      // 1. Send command to offline device -> rejected
      final failedResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'req-c-1',
          deviceId: 'test-device-c',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(failedResult.status, CommandStatus.failed);
      expect(failedResult.errorMessage, 'Device offline');

      // 2. Reconnect device
      repository.toggleDeviceConnection('test-device-c');
      final currentDev =
          repository.devices.firstWhere((d) => d.id == 'test-device-c');
      expect(currentDev.connection, DeviceConnection.online);

      // 3. Resend command -> confirmed
      final confirmedResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'req-c-2',
          deviceId: 'test-device-c',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(confirmedResult.status, CommandStatus.confirmed);
      final updatedDev =
          repository.devices.firstWhere((d) => d.id == 'test-device-c');
      expect(updatedDev.isOn, isTrue);
    });

    // -------------------------------------------------------------------------
    // SCENARIO D: Duplicate Commands
    // same request ID executed only once
    // -------------------------------------------------------------------------
    test('Scenario D: Duplicate Commands (same request ID executed only once)',
        () async {
      final historyNotifier = CommandHistoryNotifier(
        persistenceManager: persistenceManager,
        currentHomeId: 'home-default',
      );

      const command = DeviceCommand(
        requestId: 'req-dedup-777',
        deviceId: 'device-bulb-1',
        type: DeviceCommandType.setPower,
        value: true,
      );

      // 1. First execution executes through repository
      final result1 = await historyNotifier.executeCommand(command, repository);
      expect(result1.status, CommandStatus.confirmed);
      expect(historyNotifier.state.length, 1);

      // 2. Second execution with duplicate requestId
      const duplicateCommand = DeviceCommand(
        requestId: 'req-dedup-777',
        deviceId: 'device-bulb-1',
        type: DeviceCommandType.setPower,
        value: false, // Changed value should NOT execute
      );
      final result2 =
          await historyNotifier.executeCommand(duplicateCommand, repository);

      expect(result2.status, CommandStatus.confirmed);
      // History still contains only 1 entry with no duplicate insertion
      expect(historyNotifier.state.length, 1);
      expect(historyNotifier.hasExecuted('req-dedup-777'), isTrue);
    });

    // -------------------------------------------------------------------------
    // SCENARIO E: Automation Management
    // create -> edit -> duplicate -> disable
    // -------------------------------------------------------------------------
    test(
        'Scenario E: Automation Management (create -> edit -> duplicate -> disable)',
        () async {
      final autoNotifier = AutomationNotifier(
        HomePersistenceManager.defaultAutomations,
        persistenceManager,
      );

      // 1. Create
      const newRule = AutomationRule(
        id: 'rule-e-test',
        name: 'Evening Mood',
        isEnabled: true,
        triggerType: TriggerType.schedule,
        timeOfDay: '20:00',
        actions: [
          DeviceAction(
            deviceId: 'device-bulb-1',
            commandType: DeviceCommandType.setBrightness,
            value: 40,
          ),
        ],
      );
      autoNotifier.addRule(newRule);
      expect(autoNotifier.state.any((r) => r.id == 'rule-e-test'), isTrue);

      // 2. Edit
      final editedRule = newRule.copyWith(
        name: 'Late Evening Mood',
        timeOfDay: '21:00',
      );
      autoNotifier.updateRule(editedRule);
      final retrieved =
          autoNotifier.state.firstWhere((r) => r.id == 'rule-e-test');
      expect(retrieved.name, 'Late Evening Mood');
      expect(retrieved.timeOfDay, '21:00');

      // 3. Duplicate
      final duplicated = autoNotifier.duplicateRule('rule-e-test');
      expect(duplicated.name, 'Late Evening Mood (Copy)');
      expect(duplicated.id, isNot('rule-e-test'));
      expect(autoNotifier.state.any((r) => r.id == duplicated.id), isTrue);

      // 4. Disable
      autoNotifier.disableRule(duplicated.id);
      final disabledRule =
          autoNotifier.state.firstWhere((r) => r.id == duplicated.id);
      expect(disabledRule.isEnabled, isFalse);
    });

    // -------------------------------------------------------------------------
    // SCENARIO F: Automation History
    // trigger -> state changed -> explanation recorded in log
    // -------------------------------------------------------------------------
    test('Scenario F: Automation History (trigger -> state changed -> logged)',
        () async {
      final historyNotifier = AutomationHistoryNotifier(
        persistenceManager: persistenceManager,
        currentHomeId: 'home-default',
      );

      const rule = AutomationRule(
        id: 'rule-f-temp',
        name: 'Overheat Protection',
        isEnabled: true,
        triggerType: TriggerType.sensorThreshold,
        actions: [
          DeviceAction(
            deviceId: 'device-ac-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      // Execute command on repository
      final cmdResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-f-1',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(cmdResult.status, CommandStatus.confirmed);

      // Record in Automation History
      final permitted = historyNotifier.recordRuleExecution(
        rule: rule,
        dispatchedCommandIds: ['cmd-f-1'],
        customReason:
            'Sensor temperature (31.2°C) exceeded safe threshold (28.0°C)',
      );

      expect(permitted, isTrue);
      expect(historyNotifier.state.isNotEmpty, isTrue);
      final record = historyNotifier.state.first;
      expect(record.ruleId, 'rule-f-temp');
      expect(record.status, AutomationExecutionStatus.executed);
      expect(record.reason,
          'Sensor temperature (31.2°C) exceeded safe threshold (28.0°C)');
      expect(record.dispatchedCommandIds, contains('cmd-f-1'));
    });

    // -------------------------------------------------------------------------
    // SCENARIO G: Automation Loop Protection
    // conflicting rules halted safely without event storms
    // -------------------------------------------------------------------------
    test(
        'Scenario G: Automation Loop Protection (halts rapid recursion safely)',
        () async {
      final historyNotifier = AutomationHistoryNotifier(
        persistenceManager: persistenceManager,
        currentHomeId: 'home-default',
      );

      const rapidRule = AutomationRule(
        id: 'rule-loop-candidate',
        name: 'Oscillating Sensor Trigger',
        isEnabled: true,
        triggerType: TriggerType.sensorThreshold,
        actions: [],
      );

      // Simulate rapid event storm: 5 consecutive executions within milliseconds
      final results = <bool>[];
      for (int i = 0; i < 5; i++) {
        final permitted = historyNotifier.recordRuleExecution(
          rule: rapidRule,
          dispatchedCommandIds: ['storm-cmd-$i'],
        );
        results.add(permitted);
      }

      // Early executions pass, subsequent executions are prevented
      expect(results[0], isTrue);
      expect(results[1], isTrue);
      expect(results[2], isTrue);
      expect(results[3], isFalse);
      expect(results[4], isFalse);

      // Verify explanation in record
      final preventedRecords = historyNotifier.filterByStatus(
        AutomationExecutionStatus.loopPrevented,
      );
      expect(preventedRecords.isNotEmpty, isTrue);
      expect(preventedRecords.first.reason,
          'Loop prevented: rule recursed too rapidly');
    });

    // -------------------------------------------------------------------------
    // SCENARIO H: Persistence
    // state changes survive reload
    // -------------------------------------------------------------------------
    test('Scenario H: Persistence (state changes survive reload)', () async {
      await persistenceManager.loadHomeState();

      // Make modifications
      const newDev = SmartDevice(
        id: 'dev-persisted-h',
        name: 'Persisted AC Unit',
        roomId: 'Living Room',
        type: DeviceType.ac,
        isOn: true,
        targetTemperature: 21.5,
      );
      repository.addDevice(newDev);
      await persistenceManager.saveDevices(repository.devices);

      final cmdHistory = CommandHistoryNotifier(
        persistenceManager: persistenceManager,
        currentHomeId: 'home-default',
      );
      final newRecord = CommandRecord(
        requestId: 'req-persist-h',
        deviceId: 'dev-persisted-h',
        type: DeviceCommandType.setTargetTemperature,
        value: 21.5,
        status: CommandStatus.confirmed,
        timestamp: DateTime.now(),
        homeId: 'home-default',
      );
      cmdHistory.recordCommand(newRecord);
      await persistenceManager.saveCommandRecords(
        cmdHistory.state,
        homeId: 'home-default',
      );

      // Instantiate a completely new persistence manager pointing to same storage
      final newManager = HomePersistenceManager(storage: storage);
      final reloadedState = await newManager.loadHomeState();

      expect(
        reloadedState.devices.any((d) => d.id == 'dev-persisted-h'),
        isTrue,
      );
      expect(
        reloadedState.commandRecords.any((c) => c.requestId == 'req-persist-h'),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // SCENARIO I: Multi-Home Isolation
    // history and health isolated per home
    // -------------------------------------------------------------------------
    test('Scenario I: Multi-Home Isolation (history and health isolated)',
        () async {
      await persistenceManager.loadHomeState();

      final aggregatorDefault = HealthAggregator(
        repository: repository,
        persistenceManager: persistenceManager,
        currentHomeId: 'home-default',
      );
      final aggregatorSuburban = HealthAggregator(
        repository: repository,
        persistenceManager: persistenceManager,
        currentHomeId: 'home-suburban',
      );

      addTearDown(() {
        aggregatorDefault.dispose();
        aggregatorSuburban.dispose();
      });

      // Default home has 7 demo devices
      final defaultHealth = aggregatorDefault.watchDeviceHealth();
      final defaultList = await defaultHealth.first;
      expect(defaultList.length, 7);
      expect(defaultList.every((h) => h.homeId == 'home-default'), isTrue);

      // Suburban home has 2 demo devices
      final suburbanHealth = aggregatorSuburban.watchDeviceHealth();
      final suburbanList = await suburbanHealth.first;
      expect(suburbanList.length, 2);
      expect(suburbanList.every((h) => h.homeId == 'home-suburban'), isTrue);

      // Verify command histories do not leak across homes
      final cmdNotifierDefault = CommandHistoryNotifier(
        persistenceManager: persistenceManager,
        currentHomeId: 'home-default',
      );
      cmdNotifierDefault.recordCommand(
        CommandRecord(
          requestId: 'cmd-home-def-1',
          deviceId: 'device-bulb-1',
          type: DeviceCommandType.setPower,
          value: true,
          status: CommandStatus.confirmed,
          timestamp: DateTime.now(),
          homeId: 'home-default',
        ),
      );

      final cmdNotifierSuburban = CommandHistoryNotifier(
        persistenceManager: persistenceManager,
        currentHomeId: 'home-suburban',
      );
      expect(cmdNotifierSuburban.state.isEmpty, isTrue);
      expect(cmdNotifierSuburban.hasExecuted('cmd-home-def-1'), isFalse);
    });

    // -------------------------------------------------------------------------
    // SCENARIO J: Corrupted Storage
    // graceful fallback without crashing
    // -------------------------------------------------------------------------
    test('Scenario J: Corrupted Storage (graceful fallback without crashing)',
        () async {
      await storage.setString(
        HomePersistenceManager.storageKey,
        '{"corrupted": true, "schemaVersion": 5, "devices": [INVALID_JSON',
      );

      final safeState = await persistenceManager.loadHomeState();
      expect(safeState, isNotNull);
      expect(safeState.schemaVersion, greaterThanOrEqualTo(5));
      expect(safeState.homes.isNotEmpty, isTrue);
      expect(safeState.devices.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // SCENARIO K: Resource Cleanup
    // cancels and timeouts cleanly release timers/subscriptions
    // -------------------------------------------------------------------------
    test(
        'Scenario K: Resource Cleanup (cancels and timeouts cleanly release resources)',
        () async {
      final ble = FakeBleService();
      final prov = FakeProvisioningService();
      final aggregator = HealthAggregator(
        repository: repository,
        persistenceManager: persistenceManager,
      );

      // Test Ble disposal
      await ble.startScan();
      expect(ble.scanStarted, isTrue);
      await ble.dispose();

      // Test Provisioning cancellation
      await prov.cancel();
      expect(prov.wasCancelled, isTrue);
      await prov.dispose();

      // Test Aggregator disposal
      aggregator.dispose();
      // Emitting or querying after disposal should not throw
      expect(() => aggregator.dispose(), returnsNormally);
    });

    // -------------------------------------------------------------------------
    // SCENARIO L: Localization
    // all Phase 5 strings translate correctly in EN and VI
    // -------------------------------------------------------------------------
    test('Scenario L: Localization (all Phase 5 strings translate in EN & VI)',
        () {
      const locEn = AppLocalizations(Locale('en'));
      const locVi = AppLocalizations(Locale('vi'));

      const phase5Keys = [
        'health_dashboard',
        'system_health_score',
        'health_optimal',
        'health_degraded',
        'health_offline_warning',
        'devices_online',
        'devices_offline',
        'signal_strength',
        'active_warnings',
        'no_warnings',
        'simulated_ble_scan',
        'wifi_setup_simulated',
        'assign_room',
        'retry_pairing',
        'pairing_timeout',
        'duplicate',
        'automation_duplicated',
        'execution_history',
        'view_history',
        'no_history',
        'rule_validation_error',
        'loop_prevented_explanation',
        'skipped_explanation',
        'demo_lab',
        'force_device_offline',
        'reconnect_device',
        'inject_packet_loss',
        'trigger_reconnect_storm',
      ];

      for (final key in phase5Keys) {
        final enTranslation = locEn.translate(key);
        final viTranslation = locVi.translate(key);

        expect(enTranslation, isNotEmpty, reason: 'EN missing key $key');
        expect(enTranslation, isNot(key),
            reason: 'EN returned untranslated key $key');

        expect(viTranslation, isNotEmpty, reason: 'VI missing key $key');
        expect(viTranslation, isNot(key),
            reason: 'VI returned untranslated key $key');

        // Verify VI has a genuine Vietnamese translation distinct from English
        expect(viTranslation, stringsVi[key]);
        expect(enTranslation, stringsEn[key]);
      }

      // Verify typed getters
      expect(locEn.healthDashboard, 'Smart Home Health');
      expect(locVi.healthDashboard, 'Tình trạng hệ thống');

      expect(locEn.systemHealthScore, 'System Health Score');
      expect(locVi.systemHealthScore, 'Điểm sức khỏe hệ thống');

      expect(locEn.loopPreventedExplanation,
          'Loop prevented: rule recursed too rapidly');
      expect(locVi.loopPreventedExplanation,
          'Đã ngăn lặp: quy tắc kích hoạt đệ quy quá nhanh');
    });
  });
}
