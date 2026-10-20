import 'dart:math' as math;
import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Simulator for motorized smart curtains / blinds.
///
/// Simulates smooth position transition (0..100%) over virtual seconds.
class CurtainSimulator implements DeviceSimulator {
  CurtainSimulator(
    SmartDevice device, {
    this.speedPercentPerSecond = 10.0,
  })  : _device = device,
        _targetPosition = device.position.clamp(0, 100),
        _currentExact = device.position.clamp(0, 100).toDouble();

  SmartDevice _device;

  /// Speed of curtain movement in percentage points per virtual second.
  ///
  /// Default 10.0 means 0% to 100% takes 10 virtual seconds.
  final double speedPercentPerSecond;

  int _targetPosition;
  double _currentExact;

  @override
  SmartDevice get device => _device;

  int get targetPosition => _targetPosition;

  bool get isMoving => (_currentExact - _targetPosition).abs() > 0.001;

  @override
  void updateDevice(SmartDevice updated) {
    _device = updated;
    if ((_targetPosition - updated.position).abs() == 0) {
      _currentExact = updated.position.toDouble();
    }
  }

  /// Sets the desired target position (0..100).
  void setTargetPosition(int target) {
    _targetPosition = target.clamp(0, 100);
  }

  @override
  double get powerUsageWatts => isMoving ? 15.0 : 0.5;

  @override
  SmartDevice tick(
    Duration elapsedVirtualTime, {
    Map<String, dynamic> context = const {},
  }) {
    if (elapsedVirtualTime <= Duration.zero || !isMoving) {
      _device = _device.copyWith(
        position: _currentExact.round().clamp(0, 100),
        powerUsageWatts: powerUsageWatts,
      );
      return _device;
    }

    final double seconds = elapsedVirtualTime.inMicroseconds / 1000000.0;
    final double maxMove = speedPercentPerSecond * seconds;

    if (_currentExact < _targetPosition) {
      _currentExact =
          math.min(_targetPosition.toDouble(), _currentExact + maxMove);
    } else if (_currentExact > _targetPosition) {
      _currentExact =
          math.max(_targetPosition.toDouble(), _currentExact - maxMove);
    }

    final newPosition = _currentExact.round().clamp(0, 100);
    _device = _device.copyWith(
      position: newPosition,
      powerUsageWatts: powerUsageWatts,
    );
    return _device;
  }
}
