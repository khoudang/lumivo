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
import '../services/storage/home_persistence_manager.dart';

export '../features/activity/state/activity_notifier.dart'
    show activityProvider;
export '../features/automation/state/automation_notifier.dart'
    show automationProvider;
export '../features/automation/state/scenes_notifier.dart' show scenesProvider;
export '../features/notifications/state/notifications_notifier.dart'
    show notificationsProvider;
export '../features/rooms/state/rooms_notifier.dart' show roomsProvider;
export '../services/storage/home_persistence_manager.dart'
    show homePersistenceProvider, HomePersistenceManager, HomeState;

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final repository = MockDeviceRepository(persistenceManager: persistence);
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
