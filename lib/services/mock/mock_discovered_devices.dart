import '../../core/models/discovered_device.dart';
import '../../core/models/smart_device.dart';

const mockBulb = DiscoveredDevice(
  id: 'lumivo-bulb-01',
  name: 'Lumivo Aura Bulb',
  rssi: -52,
  type: DeviceType.light,
);

const mockFan = DiscoveredDevice(
  id: 'lumivo-fan-01',
  name: 'Lumivo Breeze Fan',
  rssi: -68,
  type: DeviceType.fan,
);

const mockCam = DiscoveredDevice(
  id: 'lumivo-cam-01',
  name: 'Lumivo Guardian Cam',
  rssi: -60,
  type: DeviceType.security,
);

const mockStrip = DiscoveredDevice(
  id: 'lumivo-strip-01',
  name: 'Lumivo Strip Light',
  rssi: -74,
  type: DeviceType.light,
);

const List<DiscoveredDevice> mockDiscoveredDevices = [
  mockBulb,
  mockFan,
  mockCam,
  mockStrip,
];
