import 'package:flutter/widgets.dart';
import 'simulation_engine.dart';
import 'virtual_clock.dart';

/// Monitors application lifecycle transitions to manage simulation resource usage.
///
/// When the app moves to background or inactive states ([AppLifecycleState.paused],
/// [AppLifecycleState.inactive], [AppLifecycleState.detached], [AppLifecycleState.hidden]),
/// the periodic virtual clock timer is suspended to conserve battery, CPU cycles,
/// and memory.
///
/// When returning to [AppLifecycleState.resumed], the clock is safely resumed
/// and simulation telemetry is resynchronized without creating duplicate timers
/// or duplicate stream subscriptions.
class SimulationLifecycleObserver with WidgetsBindingObserver {
  SimulationLifecycleObserver({
    SimulationEngine? engine,
    VirtualClock? clock,
    this.syncElapsedTimeOnResume = true,
    this.autoRegister = false,
  })  : engine = engine,
        clock = clock ?? engine?.clock ?? SimulationEngine.instance.clock {
    if (autoRegister) {
      register();
    }
  }

  /// Optional simulation engine reference for environmental re-synchronization.
  final SimulationEngine? engine;

  /// The virtual clock whose timer lifecycle is managed.
  final VirtualClock clock;

  /// Whether real elapsed duration while in background should be calculated
  /// and applied to the virtual clock when returning to the foreground.
  final bool syncElapsedTimeOnResume;

  /// Whether to automatically register with [WidgetsBinding.instance] during construction.
  final bool autoRegister;

  AppLifecycleState? _lastLifecycleState;
  bool _wasRunningBeforePause = false;
  DateTime? _pausedAt;
  bool _isRegistered = false;
  bool _isSuspended = false;
  int _pauseCount = 0;
  int _resumeCount = 0;
  int _duplicateStartAttemptsPrevented = 0;

  /// Most recent lifecycle state observed.
  AppLifecycleState? get lastLifecycleState => _lastLifecycleState;

  /// Whether the virtual clock was actively running immediately prior to suspension.
  bool get wasRunningBeforePause => _wasRunningBeforePause;

  /// Timestamp when the app transitioned into a background/suspended state.
  DateTime? get pausedAt => _pausedAt;

  /// Whether this observer is currently attached to [WidgetsBinding].
  bool get isRegistered => _isRegistered;

  /// Whether the observer is in a suspended (background) state.
  bool get isSuspended => _isSuspended;

  /// Total number of times background suspension was triggered.
  int get pauseCount => _pauseCount;

  /// Total number of times foreground resumption was triggered.
  int get resumeCount => _resumeCount;

  /// Count of redundant timer start invocations that were safely prevented.
  int get duplicateStartAttemptsPrevented => _duplicateStartAttemptsPrevented;

  /// Attaches this observer to the given [WidgetsBinding] or [WidgetsBinding.instance].
  void register([WidgetsBinding? binding]) {
    if (_isRegistered) return;
    final targetBinding = binding ?? WidgetsBinding.instance;
    targetBinding.addObserver(this);
    _isRegistered = true;
  }

  /// Detaches this observer from [WidgetsBinding].
  void unregister([WidgetsBinding? binding]) {
    if (!_isRegistered) return;
    final targetBinding = binding ?? WidgetsBinding.instance;
    targetBinding.removeObserver(this);
    _isRegistered = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handleBackground(state);
        break;
      case AppLifecycleState.resumed:
        _handleForeground();
        break;
    }
  }

  void _handleBackground(AppLifecycleState state) {
    if (_isSuspended) {
      // Already suspended (e.g., transition from inactive to paused)
      return;
    }

    _wasRunningBeforePause = clock.isRunning;
    _pausedAt = DateTime.now();
    _isSuspended = true;
    _pauseCount++;

    if (_wasRunningBeforePause) {
      clock.stop();
    }
  }

  void _handleForeground() {
    if (!_isSuspended && _lastLifecycleState == AppLifecycleState.resumed) {
      // App is already active; guard against spurious or redundant resume signals
      _duplicateStartAttemptsPrevented++;
      return;
    }

    _resumeCount++;
    _isSuspended = false;

    if (_wasRunningBeforePause) {
      if (syncElapsedTimeOnResume && _pausedAt != null) {
        final elapsedReal = DateTime.now().difference(_pausedAt!);
        if (elapsedReal > Duration.zero) {
          final virtualDuration = Duration(
            microseconds:
                (elapsedReal.inMicroseconds * clock.timeMultiplier).round(),
          );
          if (virtualDuration > Duration.zero) {
            if (engine != null) {
              engine!.advanceTime(virtualDuration);
            } else {
              clock.advance(virtualDuration);
            }
          }
        }
      }

      // Resume clock timer safely
      if (!clock.isRunning) {
        clock.start();
      } else {
        _duplicateStartAttemptsPrevented++;
      }
    }

    _pausedAt = null;
  }

  /// Explicitly requests simulation state re-synchronization across all listeners.
  void resynchronize() {
    if (engine != null) {
      engine!.setVirtualTime(clock.now);
    } else {
      clock.setTime(clock.now);
    }
  }

  /// Detaches observer and clears cached state.
  void dispose() {
    unregister();
    _pausedAt = null;
    _wasRunningBeforePause = false;
    _isSuspended = false;
  }
}
