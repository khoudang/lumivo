import '../../core/models/discovered_device.dart';

abstract interface class BleService {
  bool get isSupported;
  Stream<List<DiscoveredDevice>> get discoveredDevices;
  Future<void> startScan({Duration timeout = const Duration(seconds: 8)});
  Future<void> stopScan();
  Future<bool> connect(String deviceId);
  Future<void> disconnect(String deviceId);
  Future<void> dispose();
}
