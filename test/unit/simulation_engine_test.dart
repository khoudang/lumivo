import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/simulation/simulation.dart';

void main() {
  group('SimulationEngine Unit Tests', () {
    late SimulationEngine engine;
    late List<SmartDevice> initialDevices;

    setUp(() {
      initialDevices = [
        const SmartDevice(
          id: 'bulb-1',
          name: 'Living Room Light',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          brightness: 100, // 9.0W
        ),
        const SmartDevice(
          id: 'socket-1',
          name: 'Living Room Plug',
          roomId: 'Living Room',
          type: DeviceType.socket,
          isOn: true, // 120.0W
        ),
        const SmartDevice(
          id: 'ac-1',
          name: 'Living Room AC',
          roomId: 'Living Room',
          type: DeviceType.ac,
          isOn: false, // 5.0W standby
          targetTemperature: 24.0,
          currentTemperature: 28.0,
        ),
      ];

      engine = SimulationEngine(
        initialDevices: initialDevices,
        initialRules: [],
        autoStart: false,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test(
        'initializes with correct snapshot telemetry and total home power calculation',
        () {
      final snapshot = engine.currentSnapshot;
      expect(snapshot.devices.length, 3);

      // Bulb 9.0W + Socket 120.0W + AC standby 5.0W = 134.0W
      expect(snapshot.totalPowerWatts, closeTo(134.0, 0.05));
      expect(snapshot.offlineDeviceIds, isEmpty);
      expect(snapshot.ambientTemperature, inInclusiveRange(22.0, 31.0));
      expect(snapshot.ambientHumidity, inInclusiveRange(45.0, 75.0));
    });

    test(
        'advanceTime() advances clock, ticks simulators and updates snapshot stream',
        () async {
      final snapshots = <SimulationSnapshot>[];
      final sub = engine.snapshotStream.listen(snapshots.add);

      final initialTime = engine.clock.now;
      engine.advanceTime(const Duration(hours: 1));

      await Future<void>.delayed(Duration.zero);

      expect(snapshots.isNotEmpty, isTrue);
      expect(engine.currentSnapshot.virtualTime.difference(initialTime).inHours,
          1);

      await sub.cancel();
    });

    test(
        'chaos: forceDeviceOffline excludes offline device from active power calculation',
        () {
      expect(engine.currentSnapshot.totalPowerWatts, closeTo(134.0, 0.05));

      // Force socket-1 (120W) offline
      engine.forceDeviceOffline('socket-1', true);

      expect(
          engine.currentSnapshot.offlineDeviceIds.contains('socket-1'), isTrue);
      final socketDevice = engine.devices.firstWhere((d) => d.id == 'socket-1');
      expect(socketDevice.connection, DeviceConnection.offline);

      // Total power should drop from 134W to 14W (Bulb 9W + AC 5W)
      expect(engine.currentSnapshot.totalPowerWatts, closeTo(14.0, 0.05));

      // Restore socket-1 back online
      engine.forceDeviceOffline('socket-1', false);
      expect(engine.currentSnapshot.offlineDeviceIds.contains('socket-1'),
          isFalse);
      expect(engine.currentSnapshot.totalPowerWatts, closeTo(134.0, 0.05));
    });

    test(
        'chaos: forceAmbientTemperature and forceAmbientHumidity override diurnal curve',
        () {
      engine.forceAmbientTemperature(35.5);
      expect(engine.currentSnapshot.ambientTemperature, 35.5);

      engine.forceAmbientHumidity(88.0);
      expect(engine.currentSnapshot.ambientHumidity, 88.0);

      // Clearing forced ambient temperature restores diurnal computation
      engine.forceAmbientTemperature(null);
      expect(engine.currentSnapshot.ambientTemperature,
          inInclusiveRange(22.0, 31.0));

      engine.forceAmbientHumidity(null);
      expect(
          engine.currentSnapshot.ambientHumidity, inInclusiveRange(45.0, 75.0));
    });

    test(
        'chaos: triggerSimulatedSensorUpdate injects readings and triggers automation',
        () async {
      var automationFired = false;
      final sensorRule = AutomationRule(
        id: 'rule-high-temp',
        name: 'High Temp Alert',
        isEnabled: true,
        triggerType: TriggerType.sensorThreshold,
        sensorDeviceId: 'sensor-living',
        sensorProperty: 'temperature',
        operator: ComparisonOperator.greaterThan,
        thresholdValue: 30.0,
        actions: const [
          DeviceAction(
            deviceId: 'bulb-1',
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
        ],
      );

      final sensorDevice = const SmartDevice(
        id: 'sensor-living',
        name: 'Living Sensor',
        roomId: 'Living Room',
        type: DeviceType.sensor,
        isOn: true,
        currentTemperature: 25.0,
        currentHumidity: 50.0,
      );

      engine.registerDevice(sensorDevice);
      engine.automationEngine.addRule(sensorRule);
      engine.automationEngine.activityStream.listen((_) {
        automationFired = true;
      });

      // Inject high temp update 32.5°C (> 30.0°C)
      engine.triggerSimulatedSensorUpdate('sensor-living', 32.5, 60.0);

      await Future<void>.delayed(Duration.zero);

      final updatedSensor =
          engine.devices.firstWhere((d) => d.id == 'sensor-living');
      expect(updatedSensor.currentTemperature, 32.5);
      expect(updatedSensor.currentHumidity, 60.0);
      expect(automationFired, isTrue);
    });

    test('syncs with MockDeviceRepository when provided', () async {
      final repo = MockDeviceRepository(responseDelay: Duration.zero);
      final engineWithRepo = SimulationEngine(
        repository: repo,
        autoStart: false,
      );

      expect(engineWithRepo.devices.isNotEmpty, isTrue);
      // Change device in repository
      await repo.sendCommand(const DeviceCommand(
        requestId: 'req-1',
        deviceId: 'light-1',
        type: DeviceCommandType.setPower,
        value: false,
      ));

      await Future<void>.delayed(Duration.zero);

      final light = engineWithRepo.devices.firstWhere((d) => d.id == 'light-1');
      expect(light.isOn, isFalse);

      engineWithRepo.dispose();
      await repo.dispose();
    });

    test(
        'singleton SimulationEngine.instance provides accessible instance and resets cleanly',
        () {
      final instance1 = SimulationEngine.instance;
      final instance2 = SimulationEngine.instance;
      expect(identical(instance1, instance2), isTrue);

      SimulationEngine.resetInstance();
      final instance3 = SimulationEngine.instance;
      expect(identical(instance1, instance3), isFalse);

      SimulationEngine.resetInstance();
    });
  });
}
