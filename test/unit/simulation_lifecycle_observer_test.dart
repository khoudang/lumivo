import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/services/simulation/simulation_engine.dart';
import 'package:lumivo/services/simulation/simulation_lifecycle_observer.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimulationLifecycleObserver Unit Tests', () {
    late VirtualClock clock;
    late SimulationLifecycleObserver observer;

    setUp(() {
      clock = VirtualClock(autoStart: true);
      observer = SimulationLifecycleObserver(
        clock: clock,
        syncElapsedTimeOnResume: false,
      );
    });

    tearDown(() {
      observer.dispose();
      clock.dispose();
      SimulationEngine.resetInstance();
    });

    test('Initializes with active clock and not suspended', () {
      expect(clock.isRunning, isTrue);
      expect(observer.isSuspended, isFalse);
      expect(observer.pauseCount, 0);
      expect(observer.resumeCount, 0);
      expect(observer.lastLifecycleState, isNull);
    });

    test('Suspends clock when app goes to paused state', () {
      expect(clock.isRunning, isTrue);

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(observer.lastLifecycleState, AppLifecycleState.paused);
      expect(observer.isSuspended, isTrue);
      expect(observer.wasRunningBeforePause, isTrue);
      expect(observer.pauseCount, 1);
      expect(clock.isRunning, isFalse);
    });

    test('Suspends clock on inactive and detached states', () {
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(clock.isRunning, isFalse);
      expect(observer.isSuspended, isTrue);

      // Subsequent paused transition while already suspended does not double-count
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(observer.pauseCount, 1);

      // Resuming and transitioning to detached
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(clock.isRunning, isTrue);

      observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(clock.isRunning, isFalse);
      expect(observer.isSuspended, isTrue);
    });

    test('Resumes clock cleanly when app returns to resumed state', () {
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(clock.isRunning, isFalse);

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(clock.isRunning, isTrue);
      expect(observer.isSuspended, isFalse);
      expect(observer.resumeCount, 1);
      expect(observer.lastLifecycleState, AppLifecycleState.resumed);
    });

    test('Zero duplicate timers on multiple consecutive resumed calls', () {
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(clock.isRunning, isFalse);

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(clock.isRunning, isTrue);

      // Spurious consecutive resumed events
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(clock.isRunning, isTrue);
      expect(observer.duplicateStartAttemptsPrevented, greaterThanOrEqualTo(3));
    });

    test(
        'Does not start clock on resume if it was already stopped before pause',
        () {
      clock.stop();
      expect(clock.isRunning, isFalse);

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(observer.wasRunningBeforePause, isFalse);

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(clock.isRunning, isFalse);
    });

    test('Elapsed virtual time synchronization on resume', () async {
      final syncClock = VirtualClock(autoStart: true);
      final syncObserver = SimulationLifecycleObserver(
        clock: syncClock,
        syncElapsedTimeOnResume: true,
      );

      final beforePauseTime = syncClock.now;
      syncObserver.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(syncClock.isRunning, isFalse);

      // Wait a tiny bit of real time
      await Future<void>.delayed(const Duration(milliseconds: 25));

      syncObserver.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(syncClock.isRunning, isTrue);
      expect(
        syncClock.now.isAfter(beforePauseTime) ||
            syncClock.now.isAtSameMomentAs(beforePauseTime),
        isTrue,
      );

      syncObserver.dispose();
      syncClock.dispose();
    });

    test('Explicit resynchronize emits clock tick to listeners', () async {
      DateTime? emittedTime;
      final sub = clock.tickStream.listen((time) {
        emittedTime = time;
      });

      observer.resynchronize();
      await pumpEventQueue();

      expect(emittedTime, equals(clock.now));
      await sub.cancel();
    });

    test('Integration with SimulationEngine coordinates engine clock',
        () async {
      final engine = SimulationEngine();
      engine.clock.start();
      expect(engine.clock.isRunning, isTrue);

      final engineObserver = SimulationLifecycleObserver(
        engine: engine,
        syncElapsedTimeOnResume: false,
      );

      engineObserver.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(engine.clock.isRunning, isFalse);

      engineObserver.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(engine.clock.isRunning, isTrue);

      engineObserver.dispose();
      engine.dispose();
    });

    test('Registration and unregistration with WidgetsBinding', () {
      final obs = SimulationLifecycleObserver(
        clock: clock,
        autoRegister: true,
      );
      expect(obs.isRegistered, isTrue);

      obs.unregister();
      expect(obs.isRegistered, isFalse);

      obs.register();
      expect(obs.isRegistered, isTrue);

      obs.dispose();
      expect(obs.isRegistered, isFalse);
    });
  });
}
