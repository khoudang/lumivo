import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/smart_device.dart';
import '../core/repositories/device_repository.dart';
import '../services/mock/mock_device_repository.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final repository = MockDeviceRepository();
  ref.onDispose(() { repository.dispose(); });
  return repository;
});

final devicesProvider = StreamProvider<List<SmartDevice>>((ref) {
  return ref.watch(deviceRepositoryProvider).watchDevices();
});
