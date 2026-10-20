import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Simulator for smart light bulbs.
///
/// Power calculation:
/// - When On: `9W * (brightness / 100)`
/// - Standby (Off): `0.2W`
class BulbSimulator implements DeviceSimulator {
  BulbSimulator(SmartDevice device) : _device = device;

  SmartDevice _device;

  @override
  SmartDevice get device => _device;

  @override
  void updateDevice(SmartDevice updated) {
    _device = updated;
  }

  /// Calculates power consumption for a bulb in Watts.
  static double calculatePower({
    required bool isOn,
    required int brightness,
  }) {
    if (!isOn) return 0.2;
    final clampedBrightness = brightness.clamp(0, 100);
    return 9.0 * (clampedBrightness / 100.0);
  }

  @override
  double get powerUsageWatts => calculatePower(
        isOn: _device.isOn,
        brightness: _device.brightness,
      );

  void setPower(bool isOn) {
    _device = _device.copyWith(
      isOn: isOn,
      powerUsageWatts:
          calculatePower(isOn: isOn, brightness: _device.brightness),
    );
  }

  void setBrightness(int brightness) {
    final clamped = brightness.clamp(0, 100);
    _device = _device.copyWith(
      brightness: clamped,
      isOn: clamped > 0,
      powerUsageWatts: calculatePower(isOn: clamped > 0, brightness: clamped),
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
