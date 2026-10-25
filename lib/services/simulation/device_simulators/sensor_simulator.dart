import 'dart:math' as math;
import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Simulator for environmental temperature and humidity sensors.
///
/// Features:
/// - Diurnal ambient temperature cycle (22°C - 31°C) based on hour of day.
/// - Diurnal ambient humidity cycle (45% - 75%) inversely related to temperature.
/// - Thermal coupling with room AC (pulls sensor readings toward AC cooling/heating).
/// - Enforces strict physical telemetry bounds (temperature: 16-32°C, humidity: 20-90%).
class SensorSimulator implements DeviceSimulator {
  SensorSimulator(SmartDevice device) : _device = device;

  SmartDevice _device;

  double? forcedTemperature;
  double? forcedHumidity;

  @override
  SmartDevice get device => _device;

  @override
  void updateDevice(SmartDevice updated) {
    _device = updated;
  }

  /// Calculates outdoor / unconditioned ambient diurnal temperature (22°C - 31°C).
  ///
  /// Peak at ~15:00 (31°C), trough at ~03:00 (22°C).
  static double computeDiurnalTemperature(DateTime time) {
    final double hourFloat =
        time.hour + time.minute / 60.0 + time.second / 3600.0;
    final double phase = 2.0 * math.pi * (hourFloat - 9.0) / 24.0;
    final double normalized = (math.sin(phase) + 1.0) / 2.0;
    final double temp = 22.0 + (31.0 - 22.0) * normalized;
    return (temp * 100).roundToDouble() / 100.0;
  }

  /// Calculates outdoor / unconditioned ambient diurnal humidity (45% - 75%).
  ///
  /// Trough at ~15:00 (45%), peak at ~03:00 (75%).
  static double computeDiurnalHumidity(DateTime time) {
    final double hourFloat =
        time.hour + time.minute / 60.0 + time.second / 3600.0;
    final double phase = 2.0 * math.pi * (hourFloat - 9.0) / 24.0;
    final double normalized = (math.sin(phase) + 1.0) / 2.0;
    final double humidity = 75.0 - (75.0 - 45.0) * normalized;
    return (humidity * 100).roundToDouble() / 100.0;
  }

  @override
  double get powerUsageWatts => 0.05;

  @override
  SmartDevice tick(
    Duration elapsedVirtualTime, {
    Map<String, dynamic> context = const {},
  }) {
    final DateTime virtualTime =
        context['virtualTime'] as DateTime? ?? DateTime.now();

    double temp = forcedTemperature ??
        (context['forcedTemperature'] as num?)?.toDouble() ??
        computeDiurnalTemperature(virtualTime);

    double humidity = forcedHumidity ??
        (context['forcedHumidity'] as num?)?.toDouble() ??
        computeDiurnalHumidity(virtualTime);

    // If an AC is active in the same room or context, adjust the sensor temperature & humidity
    final acTemp = (context['acTemperature'] as num?)?.toDouble() ??
        (context['roomAcTemperature'] as num?)?.toDouble();
    final bool isAcActive = context['isAcActive'] as bool? ?? (acTemp != null);

    if (isAcActive && acTemp != null && forcedTemperature == null) {
      // Room sensor temperature is strongly pulled toward active AC temperature
      temp = (0.75 * acTemp + 0.25 * temp);
      // AC cooling reduces humidity (dehumidification effect)
      if (forcedHumidity == null) {
        humidity = math.max(40.0, humidity - 8.0);
      }
    }

    // Telemetry bounds audit: enforce 16.0 - 32.0 °C and 20.0 - 90.0 %
    final clampedTemp = temp.clamp(16.0, 32.0);
    final clampedHumidity = humidity.clamp(20.0, 90.0);

    final roundedTemp = (clampedTemp * 100).roundToDouble() / 100.0;
    final roundedHumidity = (clampedHumidity * 100).roundToDouble() / 100.0;

    _device = _device.copyWith(
      currentTemperature: roundedTemp,
      currentHumidity: roundedHumidity,
      powerUsageWatts: powerUsageWatts,
    );
    return _device;
  }
}
