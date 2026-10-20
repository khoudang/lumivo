import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/smart_device.dart';
import '../core/repositories/device_repository.dart';
import '../services/ble/ble_service.dart';
import '../services/ble/ble_service_factory.dart';
import '../services/mock/mock_device_repository.dart';
import '../services/mqtt/mock_mqtt_service.dart';
import '../services/mqtt/mqtt_service.dart';
import '../services/provisioning/mock_provisioning_service.dart';
import '../services/provisioning/provisioning_service.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final repository = MockDeviceRepository();
  ref.onDispose(() {
    repository.dispose();
  });
  return repository;
});

final devicesProvider = StreamProvider<List<SmartDevice>>((ref) {
  return ref.watch(deviceRepositoryProvider).watchDevices();
});

final bleServiceProvider = Provider<BleService>((ref) {
  return BleServiceFactory.instance;
});

final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MockMqttService();
  ref.onDispose(() => service.dispose());
  return service;
});

final provisioningServiceProvider = Provider<ProvisioningService>((ref) {
  return MockProvisioningService();
});
