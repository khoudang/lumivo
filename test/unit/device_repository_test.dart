import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('MockDeviceRepository Unit Tests', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('initial devices list contains default devices', () async {
      final initialDevices = repository.devices;
      expect(initialDevices.length, 6);
      expect(
        initialDevices.map((d) => d.id),
        containsAll([
          'light-1',
          'fan-1',
          'security-1',
          'light-2',
          'fan-2',
          'light-3',
        ]),
      );

      final streamDevices = await repository.watchDevices().first;
      expect(streamDevices.length, 6);
      expect(streamDevices.first.id, 'light-1');
    });

    test('sendCommand setPower updates device power state', () async {
      final result = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-power-1',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: false,
        ),
      );

      expect(result.status, CommandStatus.confirmed);
      final updated = repository.devices.firstWhere((d) => d.id == 'light-1');
      expect(updated.isOn, isFalse);

      final resultOn = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-power-2',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(resultOn.status, CommandStatus.confirmed);
      expect(
        repository.devices.firstWhere((d) => d.id == 'light-1').isOn,
        isTrue,
      );

      final invalidResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-power-3',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: 'invalid',
        ),
      );
      expect(invalidResult.status, CommandStatus.failed);
      expect(invalidResult.errorMessage, 'Expected boolean');
    });

    test('sendCommand setBrightness clamps values between 0 and 100', () async {
      final resultOver = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-bright-1',
          deviceId: 'light-1',
          type: DeviceCommandType.setBrightness,
          value: 125,
        ),
      );
      expect(resultOver.status, CommandStatus.confirmed);
      final lightOver = repository.devices.firstWhere((d) => d.id == 'light-1');
      expect(lightOver.brightness, 100);
      expect(lightOver.isOn, isTrue);

      final resultUnder = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-bright-2',
          deviceId: 'light-1',
          type: DeviceCommandType.setBrightness,
          value: -15,
        ),
      );
      expect(resultUnder.status, CommandStatus.confirmed);
      final lightUnder =
          repository.devices.firstWhere((d) => d.id == 'light-1');
      expect(lightUnder.brightness, 0);
      expect(lightUnder.isOn, isFalse);

      final fanResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-bright-3',
          deviceId: 'fan-1',
          type: DeviceCommandType.setBrightness,
          value: 50,
        ),
      );
      expect(fanResult.status, CommandStatus.failed);
      expect(fanResult.errorMessage, 'Unsupported brightness');
    });

    test('command failure on offline device', () async {
      repository.toggleDeviceConnection('light-1');
      final offlineLight =
          repository.devices.firstWhere((d) => d.id == 'light-1');
      expect(offlineLight.connection, DeviceConnection.offline);

      final result = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-offline-1',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: false,
        ),
      );

      expect(result.status, CommandStatus.failed);
      expect(result.errorMessage, 'Device offline');

      repository.toggleDeviceConnection('light-1');
      final onlineLight =
          repository.devices.firstWhere((d) => d.id == 'light-1');
      expect(onlineLight.connection, DeviceConnection.online);

      final retryResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-online-retry',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: false,
        ),
      );
      expect(retryResult.status, CommandStatus.confirmed);
    });

    test('addDevice emits updated stream', () async {
      const newDevice = SmartDevice(
        id: 'lumivo-bulb-01',
        name: 'Lumivo Aura Bulb',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: true,
        brightness: 90,
      );

      expectLater(
        repository.watchDevices(),
        emitsInOrder([
          hasLength(6),
          hasLength(7),
        ]),
      );

      repository.addDevice(newDevice);

      expect(repository.devices.length, 7);
      expect(repository.devices.any((d) => d.id == 'lumivo-bulb-01'), isTrue);
    });

    test('resetToDefaults restores original devices list and emits to stream',
        () async {
      repository.addDevice(
        const SmartDevice(
          id: 'temp-1',
          name: 'Temp Device',
          roomId: 'Kitchen',
          type: DeviceType.fan,
          isOn: false,
        ),
      );
      expect(repository.devices.length, 7);

      expectLater(
        repository.watchDevices(),
        emitsInOrder([
          hasLength(7),
          hasLength(6),
        ]),
      );

      repository.resetToDefaults();
      expect(repository.devices.length, 6);
      expect(repository.devices.any((d) => d.id == 'temp-1'), isFalse);
    });

    test('command on non-existent device fails', () async {
      final result = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-missing-1',
          deviceId: 'non-existent',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(result.status, CommandStatus.failed);
      expect(result.errorMessage, 'Device not found');
    });
  });
}
