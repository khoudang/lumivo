import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/services/ble/ble_service.dart';
import 'package:lumivo/services/ble/ble_service_factory.dart';
import 'package:lumivo/services/ble/mock_ble_service.dart';

void main() {
  group('MockBleService', () {
    late MockBleService service;

    setUp(() {
      service = MockBleService(
        connectionLatency: Duration.zero,
        disconnectionLatency: Duration.zero,
        rssiUpdateInterval: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test('implements BleService and is supported', () {
      expect(service, isA<BleService>());
      expect(service.isSupported, isTrue);
    });

    test('discovers mock Lumivo devices on startScan', () async {
      final devicesFuture = service.discoveredDevices.first;

      await service.startScan();
      final devices = await devicesFuture;

      expect(devices, isNotEmpty);
      expect(devices.any((d) => d.name == 'Lumivo Bulb A19'), isTrue);
      expect(devices.any((d) => d.name == 'Lumivo Smart Plug'), isTrue);
      expect(devices.any((d) => d.name == 'Lumivo Ambient Sensor'), isTrue);
      expect(devices.any((d) => d.name == 'Lumivo LED Strip'), isTrue);
    });

    test('RSSI values are within realistic bounds (-82 dBm to -45 dBm)',
        () async {
      final devicesFuture = service.discoveredDevices.first;
      await service.startScan();
      final devices = await devicesFuture;

      for (final device in devices) {
        expect(device.rssi, greaterThanOrEqualTo(-82));
        expect(device.rssi, lessThanOrEqualTo(-45));
      }
    });

    test('auto-stops scan after timeout', () async {
      await service.startScan(timeout: const Duration(milliseconds: 50));
      expect(service.isScanning, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(service.isScanning, isFalse);
    });

    test('connects and disconnects existing device', () async {
      const deviceId = 'lumivo-ble-bulb-a19';
      final connected = await service.connect(deviceId);
      expect(connected, isTrue);
      expect(service.connectedDeviceIds.contains(deviceId), isTrue);

      await service.disconnect(deviceId);
      expect(service.connectedDeviceIds.contains(deviceId), isFalse);
    });

    test('fails to connect unknown device', () async {
      final connected = await service.connect('non-existent-device');
      expect(connected, isFalse);
      expect(service.connectedDeviceIds, isEmpty);
    });
  });

  group('BleServiceFactory', () {
    test('returns MockBleService by default and for web', () {
      final ble = BleServiceFactory.create();
      expect(ble, isA<MockBleService>());
      expect(BleServiceFactory.instance, isA<BleService>());
    });

    test('allows setting a mock instance for testing', () {
      final customMock = MockBleService();
      BleServiceFactory.setMockInstance(customMock);
      expect(identical(BleServiceFactory.instance, customMock), isTrue);

      BleServiceFactory.setMockInstance(null); // Reset
    });
  });
}
