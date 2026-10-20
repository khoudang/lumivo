import '../../../core/models/smart_device.dart';
import 'device_simulator.dart';

/// Simulator for smart door locks.
///
/// Features lock state control and configurable auto-lock countdown timer.
class LockSimulator implements DeviceSimulator {
  LockSimulator(
    SmartDevice device, {
    this.autoLockEnabled = true,
    this.autoLockDelay = const Duration(seconds: 30),
  })  : _device = device,
        _unlockedDuration = Duration.zero;

  SmartDevice _device;

  /// Whether auto-lock countdown is enabled when unlocked.
  bool autoLockEnabled;

  /// Duration to wait before auto-locking after being unlocked.
  Duration autoLockDelay;

  Duration _unlockedDuration;

  @override
  SmartDevice get device => _device;

  Duration get unlockedDuration => _unlockedDuration;

  @override
  void updateDevice(SmartDevice updated) {
    if (_device.isLocked != updated.isLocked) {
      _unlockedDuration = Duration.zero;
    }
    _device = updated;
  }

  /// Unlocks the door and resets the auto-lock timer.
  void unlock() {
    _device = _device.copyWith(isLocked: false);
    _unlockedDuration = Duration.zero;
  }

  /// Locks the door and clears the auto-lock timer.
  void lock() {
    _device = _device.copyWith(isLocked: true);
    _unlockedDuration = Duration.zero;
  }

  @override
  double get powerUsageWatts => _device.isLocked ? 0.1 : 0.8;

  @override
  SmartDevice tick(
    Duration elapsedVirtualTime, {
    Map<String, dynamic> context = const {},
  }) {
    if (elapsedVirtualTime <= Duration.zero) {
      _device = _device.copyWith(powerUsageWatts: powerUsageWatts);
      return _device;
    }

    if (!_device.isLocked && autoLockEnabled) {
      _unlockedDuration += elapsedVirtualTime;
      if (_unlockedDuration >= autoLockDelay) {
        _device = _device.copyWith(isLocked: true);
        _unlockedDuration = Duration.zero;
      }
    }

    _device = _device.copyWith(
      powerUsageWatts: powerUsageWatts,
    );
    return _device;
  }
}
