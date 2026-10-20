import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Speed settings for smart fans.
enum FanSpeed {
  low(15.0),
  medium(35.0),
  high(55.0);

  const FanSpeed(this.wattage);
  final double wattage;

  static FanSpeed fromValue(dynamic val) {
    if (val is FanSpeed) return val;
    if (val is String) {
      switch (val.toLowerCase().trim()) {
        case 'low':
        case '1':
          return FanSpeed.low;
        case 'medium':
        case 'med':
        case '2':
          return FanSpeed.medium;
        case 'high':
        case '3':
          return FanSpeed.high;
      }
    }
    if (val is num) {
      if (val <= 1) return FanSpeed.low;
      if (val == 2) return FanSpeed.medium;
      return FanSpeed.high;
    }
    return FanSpeed.medium;
  }
}

/// Simulator for smart fans.
///
/// Power calculation:
/// - When On: Low (15W), Medium (35W), High (55W)
/// - Standby (Off): 0.5W
class FanSimulator implements DeviceSimulator {
  FanSimulator(
    SmartDevice device, {
    FanSpeed defaultSpeed = FanSpeed.medium,
  })  : _device = device,
        _speed = device.customData.containsKey('speed')
            ? FanSpeed.fromValue(device.customData['speed'])
            : defaultSpeed;

  SmartDevice _device;
  FanSpeed _speed;

  @override
  SmartDevice get device => _device;

  FanSpeed get speed => _speed;

  @override
  void updateDevice(SmartDevice updated) {
    _device = updated;
    if (updated.customData.containsKey('speed')) {
      _speed = FanSpeed.fromValue(updated.customData['speed']);
    }
  }

  void setSpeed(FanSpeed newSpeed) {
    _speed = newSpeed;
    final updatedData = Map<String, dynamic>.from(_device.customData);
    updatedData['speed'] = newSpeed.name;
    _device = _device.copyWith(
      customData: updatedData,
      powerUsageWatts: powerUsageWatts,
    );
  }

  void setPower(bool isOn) {
    _device = _device.copyWith(
      isOn: isOn,
      powerUsageWatts: calculatePower(isOn: isOn, speed: _speed),
    );
  }

  /// Calculates power consumption in Watts for a fan.
  static double calculatePower({
    required bool isOn,
    FanSpeed speed = FanSpeed.medium,
  }) {
    if (!isOn) return 0.5;
    return speed.wattage;
  }

  @override
  double get powerUsageWatts => calculatePower(
        isOn: _device.isOn,
        speed: _speed,
      );

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
