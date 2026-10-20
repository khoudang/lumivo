import '../../../core/models/smart_device.dart';

/// Base interface for all virtual device simulators in the smart home engine.
abstract class DeviceSimulator {
  /// The underlying [SmartDevice] model and current state.
  SmartDevice get device;

  /// Updates the internal device state representation.
  void updateDevice(SmartDevice updated);

  /// Current power consumption in Watts.
  double get powerUsageWatts;

  /// Advances device state over [elapsedVirtualTime].
  ///
  /// Optional [context] can contain environmental data such as ambient temperature
  /// and humidity. Returns the updated [SmartDevice].
  SmartDevice tick(
    Duration elapsedVirtualTime, {
    Map<String, dynamic> context = const {},
  });
}
