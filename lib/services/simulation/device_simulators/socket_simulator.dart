import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Simulator for smart sockets / plugs.
///
/// Power: 120W when On, 0W when Off.
class SocketSimulator implements DeviceSimulator {
  SocketSimulator(SmartDevice device) : _device = device;

  SmartDevice _device;

  @override
  SmartDevice get device => _device;

  @override
  void updateDevice(SmartDevice updated) {
    _device = updated;
  }

  /// Calculates socket power in Watts.
  static double calculatePower({required bool isOn}) {
    return isOn ? 120.0 : 0.0;
  }

  @override
  double get powerUsageWatts => calculatePower(isOn: _device.isOn);

  void setPower(bool isOn) {
    _device = _device.copyWith(
      isOn: isOn,
      powerUsageWatts: calculatePower(isOn: isOn),
    );
  }

  @override
  SmartDevice tick(
    Duration elapsedVirtualTime, {
    Map<String, dynamic> context = const {},
  }) {
    _device = _device.copyWith(
      powerUsageWatts: powerUsageWatts,
    );
    return _device;
  }
}
