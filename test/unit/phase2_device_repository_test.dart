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
      // 1. Valid range command
      var res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'test-ac-1',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 19.5,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-ac-1')
            .targetTemperature,
        19.5,
      );

      // 2. Below minimum clamping (12.0 -> 16.0)
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'test-ac-low',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 12.0,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-ac-1')
            .targetTemperature,
        16.0,
      );

      // 3. Above maximum clamping (35.0 -> 30.0)
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'test-ac-high',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 35.0,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-ac-1')
            .targetTemperature,
        30.0,
      );

      // 4. Invalid data type fails safely
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'test-ac-invalid',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 'twenty-two',
        ),
      );
      expect(res.status, CommandStatus.failed);
    });

    test('Curtain position command clamps between 0 and 100', () async {
      // 1. Normal position
      var res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'curt-1',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: 45,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        45,
      );

      // 2. Below 0 clamping
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'curt-low',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: -15,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        0,
      );

      // 3. Above 100 clamping
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'curt-high',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: 125,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        100,
      );

      // 4. Invalid non-number type fails
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'curt-invalid',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: true,
        ),
      );
      expect(res.status, CommandStatus.failed);
    });

    test('Smart lock commands (setLock & toggleLock) update lock state',
        () async {
      final initialLock =
          repository.devices.firstWhere((d) => d.id == 'device-lock-1');
      expect(initialLock.isLocked, isTrue);

      // Unlock
      var res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'lock-cmd-1',
          deviceId: 'device-lock-1',
          type: DeviceCommandType.setLock,
          value: false,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-lock-1').isLocked,
        isFalse,
      );

      // Toggle back to locked
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'lock-cmd-2',
          deviceId: 'device-lock-1',
          type: DeviceCommandType.toggleLock,
          value: true,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-lock-1').isLocked,
        isTrue,
      );

      // Toggle back to unlocked
      res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'lock-cmd-3',
          deviceId: 'device-lock-1',
          type: DeviceCommandType.toggleLock,
          value: false,
        ),
      );
      expect(res.status, CommandStatus.confirmed);
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-lock-1').isLocked,
        isFalse,
      );
    });

    test('Offline device rejects all commands safely', () async {
      // Toggle Bedroom AC offline
      repository.toggleDeviceConnection('device-ac-1');
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-ac-1').connection,
        DeviceConnection.offline,
      );

      // Attempt command while offline
      final res = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'offline-cmd',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setPower,
          value: false,
        ),
      );

      expect(res.status, CommandStatus.failed);
      expect(res.errorMessage, 'Device offline');

      // Toggle back online and verify command succeeds
      repository.toggleDeviceConnection('device-ac-1');
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-ac-1').connection,
        DeviceConnection.online,
      );

      final onlineRes = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'online-cmd',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setPower,
          value: false,
        ),
      );
      expect(onlineRes.status, CommandStatus.confirmed);
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

      await Future<void>.delayed(const Duration(milliseconds: 10));

      await repository.sendCommand(
        const DeviceCommand(
          requestId: 'stream-cmd-1',
          deviceId: 'device-ac-1',
          type: DeviceCommandType.setTargetTemperature,
          value: 23.0,
        ),
      );

      repository.addDevice(
        const SmartDevice(
          id: 'test-new-dev',
          name: 'Balcony Light',
          roomId: 'Balcony',
          type: DeviceType.light,
          isOn: false,
        ),
      );
    });

    test('resetToDemo restores seed devices and syncs with persistence',
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
      expect(repository.devices.length,
          HomePersistenceManager.allDemoDevices.length);
      expect(repository.devices.any((d) => d.id == 'custom-dev'), isFalse);

      final persistedState = await persistence.loadHomeState();
      expect(persistedState.devices.length,
          HomePersistenceManager.allDemoDevices.length);
      expect(persistedState.devices.any((d) => d.id == 'custom-dev'), isFalse);
    });
  });
}
