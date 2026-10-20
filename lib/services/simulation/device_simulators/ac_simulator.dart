import 'dart:math' as math;
import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Simulator for smart Air Conditioners (AC).
///
/// Thermodynamics:
/// - If AC is On, pulls room temperature toward [targetTemperature] by 0.05°C per virtual minute.
/// - Power: 1200W when active (On), 5W standby (Off).
class AcSimulator implements DeviceSimulator {
  AcSimulator(SmartDevice device) : _device = device;

  SmartDevice _device;

  @override
  SmartDevice get device => _device;

  @override
  void updateDevice(SmartDevice updated) {
    _device = updated;
  }

  /// Calculates AC power in Watts.
  static double calculatePower({required bool isOn}) {
    return isOn ? 1200.0 : 5.0;
  }

  @override
  double get powerUsageWatts => calculatePower(isOn: _device.isOn);

  void setPower(bool isOn) {
    _device = _device.copyWith(
      isOn: isOn,
      powerUsageWatts: calculatePower(isOn: isOn),
    );
  }

  void setTargetTemperature(double temp) {
    _device = _device.copyWith(
      targetTemperature: temp.clamp(16.0, 30.0),
    );
  }

  @override
  SmartDevice tick(
    Duration elapsedVirtualTime, {
    Map<String, dynamic> context = const {},
  }) {
    if (elapsedVirtualTime <= Duration.zero) {
      _device = _device.copyWith(powerUsageWatts: powerUsageWatts);
      return _device;
    }

    double current = _device.currentTemperature;
    final target = _device.targetTemperature;
    final double minutes =
        elapsedVirtualTime.inMicroseconds / (60.0 * 1000000.0);

    if (_device.isOn) {
      final double pullDelta = 0.05 * minutes;
      if (current > target) {
        current = math.max(target, current - pullDelta);
      } else if (current < target) {
        current = math.min(target, current + pullDelta);
      }
    } else if (context.containsKey('ambientTemperature')) {
      final ambient = (context['ambientTemperature'] as num).toDouble();
      final double driftDelta = 0.01 * minutes;
      if (current > ambient) {
        current = math.max(ambient, current - driftDelta);
      } else if (current < ambient) {
        current = math.min(ambient, current + driftDelta);
      }
    }

    // Keep numerical precision clean to 4 decimal places
    final roundedTemp = (current * 10000).roundToDouble() / 10000.0;

    _device = _device.copyWith(
      currentTemperature: roundedTemp,
      powerUsageWatts: powerUsageWatts,
    );
    return _device;
  }
}
