import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 2 MockDeviceRepository Unit Tests', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistence;
    late MockDeviceRepository repository;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistence = HomePersistenceManager(storage: storage);
      await persistence.resetDemoData();
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: HomePersistenceManager.defaultDemoDevices,
        persistenceManager: persistence,
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('All 7 Phase 2 device types are supported and loaded', () {
      final devices = repository.devices;
      expect(devices.length, 7);
      final types = devices.map((d) => d.type).toSet();
      expect(
        types,
        containsAll([
          DeviceType.light,
          DeviceType.fan,
          DeviceType.ac,
          DeviceType.socket,
          DeviceType.curtain,
          DeviceType.lock,
          DeviceType.sensor,
        ]),
      );
    });

    test('AC target temperature command clamps between 16 and 30 deg C',
        () async {
      // Normal temperature
      final res1 = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-ac-1',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 23.5,
        ),
      );
      expect(res1.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-ac-1')
            .targetTemperature,
        23.5,
      );

      // Clamp low
      final resLow = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-ac-low',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 12.0,
        ),
      );
      expect(resLow.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-ac-1')
            .targetTemperature,
        16.0,
      );

      // Clamp high
      final resHigh = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-ac-high',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 36.0,
        ),
      );
      expect(resHigh.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-ac-1')
            .targetTemperature,
        30.0,
      );

      // Invalid input type
      final resErr = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-ac-err',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 'invalid',
        ),
      );
      expect(resErr.status, CommandStatus.failed);
      expect(resErr.errorMessage, 'Expected number for temperature');
    });

    test('Curtain position command clamps between 0 and 100', () async {
      // Normal position
      final resNormal = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-curtain-1',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: 75,
        ),
      );
      expect(resNormal.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        75,
      );

      // Below 0
      final resUnder = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-curtain-under',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: -20,
        ),
      );
      expect(resUnder.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        0,
      );

      // Over 100
      final resOver = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-curtain-over',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: 120,
        ),
      );
      expect(resOver.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        100,
      );
    });

    test('Smart lock commands (setLock & toggleLock) update lock state',
        () async {
      final lockDevice =
          repository.devices.firstWhere((d) => d.id == 'device-lock-1');
      expect(lockDevice.isLocked, isTrue);

      // Unlock via setLock
      final resUnlock = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-lock-1',
          deviceId: 'device-lock-1',
          type: DeviceCommandType.setLock,
          value: false,
        ),
      );
      expect(resUnlock.status, CommandStatus.confirmed);
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-lock-1').isLocked,
        isFalse,
      );

      // Toggle lock (false -> true)
      final resToggle = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-lock-toggle',
          deviceId: 'device-lock-1',
          type: DeviceCommandType.toggleLock,
          value: true,
        ),
      );
      expect(resToggle.status, CommandStatus.confirmed);
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-lock-1').isLocked,
        isTrue,
      );

      // Invalid setLock input
      final resErr = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-lock-err',
          deviceId: 'device-lock-1',
          type: DeviceCommandType.setLock,
          value: 'not-bool',
        ),
      );
      expect(resErr.status, CommandStatus.failed);
      expect(resErr.errorMessage, 'Expected boolean for lock');
    });

    test('Offline device rejects all commands safely', () async {
      repository.toggleDeviceConnection('device-ac-1');
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-ac-1').connection,
        DeviceConnection.offline,
      );

      final result = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-ac-offline',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 20.0,
        ),
      );
      expect(result.status, CommandStatus.failed);
      expect(result.errorMessage, 'Device offline');

      // Reconnect
      repository.toggleDeviceConnection('device-ac-1');
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-ac-1').connection,
        DeviceConnection.online,
      );

      final retryResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-ac-retry',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 20.0,
        ),
      );
      expect(retryResult.status, CommandStatus.confirmed);
    });

    test('watchDevices stream emits updates on commands and additions',
        () async {
      expectLater(
        repository.watchDevices(),
        emitsInOrder([
          hasLength(7), // initial
          hasLength(7), // target temperature changed
          hasLength(8), // new device added
        ]),
      );

      await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-stream-1',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 25.0,
        ),
      );

      repository.addDevice(
        const SmartDevice(
          id: 'device-extra-1',
          name: 'Extra Light',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: false,
        ),
      );
    });

    test('resetToDemo restores 7 seed devices and syncs with persistence',
        () async {
      repository.addDevice(
        const SmartDevice(
          id: 'custom-dev',
          name: 'Custom Sensor',
          roomId: 'Office',
          type: DeviceType.sensor,
          isOn: true,
        ),
      );
      expect(repository.devices.length, 8);

      repository.resetToDemo();
      expect(repository.devices.length, 7);
      expect(repository.devices.any((d) => d.id == 'custom-dev'), isFalse);

      final persistedState = await persistence.loadHomeState();
      expect(persistedState.devices.length, 7);
      expect(persistedState.devices.any((d) => d.id == 'custom-dev'), isFalse);
    });
  });
}
