import 'dart:async';
import 'dart:math';

import '../../core/models/discovered_device.dart';
import '../../core/models/smart_device.dart';
import 'ble_service.dart';

class MockBleService implements BleService {
  MockBleService({
    List<DiscoveredDevice>? initialDevices,
    this.connectionLatency = const Duration(milliseconds: 300),
    this.disconnectionLatency = const Duration(milliseconds: 150),
    this.rssiUpdateInterval = const Duration(seconds: 1),
    Random? random,
  })  : _random = random ?? Random(),
        _mockDevices = initialDevices ?? defaultMockDevices;

  static const List<DiscoveredDevice> defaultMockDevices = [
    DiscoveredDevice(
      id: 'lumivo-ble-bulb-a19',
      name: 'Lumivo Bulb A19',
      rssi: -52,
      type: DeviceType.light,
      advertisedServiceUuid: '0000fe01-0000-1000-8000-00805f9b34fb',
      isProvisioned: false,
    ),
    DiscoveredDevice(
      id: 'lumivo-ble-smart-plug',
      name: 'Lumivo Smart Plug',
      rssi: -64,
      type: DeviceType.fan,
      advertisedServiceUuid: '0000fe02-0000-1000-8000-00805f9b34fb',
      isProvisioned: false,
    ),
    DiscoveredDevice(
      id: 'lumivo-ble-ambient-sensor',
      name: 'Lumivo Ambient Sensor',
      rssi: -71,
      type: DeviceType.security,
      advertisedServiceUuid: '0000fe03-0000-1000-8000-00805f9b34fb',
      isProvisioned: false,
    ),
    DiscoveredDevice(
      id: 'lumivo-ble-led-strip',
      name: 'Lumivo LED Strip',
      rssi: -58,
      type: DeviceType.light,
      advertisedServiceUuid: '0000fe04-0000-1000-8000-00805f9b34fb',
      isProvisioned: false,
    ),
  ];

  final Duration connectionLatency;
  final Duration disconnectionLatency;
  final Duration rssiUpdateInterval;
  final Random _random;
  final List<DiscoveredDevice> _mockDevices;

  final _discoveredController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final Set<String> _connectedDeviceIds = <String>{};
  List<DiscoveredDevice> _currentDevices = [];

  bool _isScanning = false;
  Timer? _scanTimeoutTimer;
  Timer? _rssiJitterTimer;

  @override
  bool get isSupported => true;

  bool get isScanning => _isScanning;

  Set<String> get connectedDeviceIds => Set.unmodifiable(_connectedDeviceIds);

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _discoveredController.stream;

  @override
  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (_isScanning) {
      await stopScan();
    }

    _isScanning = true;
    _currentDevices = _mockDevices.map((d) => d.copyWith()).toList();
    if (!_discoveredController.isClosed) {
      _discoveredController.add(List.unmodifiable(_currentDevices));
    }

    _rssiJitterTimer?.cancel();
    _rssiJitterTimer = Timer.periodic(rssiUpdateInterval, (_) {
      if (!_isScanning) return;
      _currentDevices = _currentDevices.map((device) {
        final delta = _random.nextInt(9) - 4; // -4 to +4
        final newRssi = (device.rssi + delta).clamp(-82, -45);
        return device.copyWith(rssi: newRssi);
      }).toList();

      if (!_discoveredController.isClosed) {
        _discoveredController.add(List.unmodifiable(_currentDevices));
      }
    });

    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(timeout, () {
      stopScan();
    });
  }

  @override
  Future<void> stopScan() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    _rssiJitterTimer?.cancel();
    _rssiJitterTimer = null;
    _isScanning = false;
  }

  @override
  Future<bool> connect(String deviceId) async {
    if (connectionLatency > Duration.zero) {
      await Future<void>.delayed(connectionLatency);
    }

    final exists = _mockDevices.any((d) => d.id == deviceId) ||
        _currentDevices.any((d) => d.id == deviceId);
    if (!exists) {
      return false;
    }

    _connectedDeviceIds.add(deviceId);
    return true;
  }

  @override
  Future<void> disconnect(String deviceId) async {
    if (disconnectionLatency > Duration.zero) {
      await Future<void>.delayed(disconnectionLatency);
    }
    _connectedDeviceIds.remove(deviceId);
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    _connectedDeviceIds.clear();
    await _discoveredController.close();
  }
}
