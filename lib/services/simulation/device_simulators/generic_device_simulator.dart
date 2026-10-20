import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Generic fallback simulator for standard on/off devices.
class GenericDeviceSimulator implements DeviceSimulator {
  GenericDeviceSimulator(SmartDevice device) : _device = device;

  SmartDevice _device;

  @override
  SmartDevice get device => _device;

  @override
  void updateDevice(SmartDevice updated) {
    _device = updated;
  }

  @override
  double get powerUsageWatts => _device.isOn ? 5.0 : 0.5;

  @override
  SmartDevice tick(
    Duration elapsedVirtualTime, {
    Map<String, dynamic> context = const {},
  }) {
    _device = _device.copyWith(powerUsageWatts: powerUsageWatts);
    return _device;
  }
}
