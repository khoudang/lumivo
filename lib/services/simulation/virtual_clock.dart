import 'dart:async';

/// Controllable virtual clock for deterministic smart home simulation.
///
/// Supports accelerated simulation (e.g. 10x, 60x, 300x) and manual time stepping.
class VirtualClock {
  VirtualClock({
    DateTime? initialTime,
    double initialMultiplier = 1.0,
    Duration realTickInterval = const Duration(seconds: 1),
    bool autoStart = false,
  })  : _now = initialTime ?? DateTime(2026, 10, 20, 8, 30),
        _timeMultiplier = initialMultiplier > 0 ? initialMultiplier : 1.0,
        _realTickInterval = realTickInterval {
    _tickController = StreamController<DateTime>.broadcast();
    if (autoStart) {
      start();
    }
  }

  DateTime _now;
  double _timeMultiplier;
  final Duration _realTickInterval;
  Timer? _timer;
  late final StreamController<DateTime> _tickController;
  bool _isDisposed = false;

  /// Current simulated virtual time.
  DateTime get now => _now;

  /// Multiplier applied to elapsed real time to calculate virtual time progression.
  double get timeMultiplier => _timeMultiplier;

  /// Whether the virtual clock's periodic timer is actively running.
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Stream of emitted virtual timestamps on each clock advance or tick.
  Stream<DateTime> get tickStream => _tickController.stream;

  /// Sets the speed multiplier (e.g. 1.0 for real-time, 10.0, 60.0, 300.0).
  ///
  /// Multipliers less than or equal to 0 are ignored or clamped to 0.0.
  void setMultiplier(double multiplier) {
    _timeMultiplier = multiplier < 0.0 ? 0.0 : multiplier;
  }

  /// Explicitly sets the virtual time to [time].
  void setTime(DateTime time) {
    _now = time;
    _emitTick();
  }

  /// Manually advances the virtual clock by [duration].
  ///
  /// Useful for deterministic, fast-forwarding unit tests without waiting for real timers.
  void advance(Duration duration) {
    if (duration == Duration.zero) return;
    _now = _now.add(duration);
    _emitTick();
  }

  /// Starts the periodic timer to automatically advance time at [_realTickInterval].
  void start() {
    if (_isDisposed || isRunning) return;
    _timer = Timer.periodic(_realTickInterval, (_) {
      if (_timeMultiplier > 0) {
        final virtualMicroseconds =
            (_realTickInterval.inMicroseconds * _timeMultiplier).round();
        advance(Duration(microseconds: virtualMicroseconds));
      }
    });
  }

  /// Pauses the periodic clock timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _emitTick() {
    if (!_tickController.isClosed) {
      _tickController.add(_now);
    }
  }

  /// Disposes the clock and cancels any active timers and stream controllers.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    stop();
    _tickController.close();
  }
}
