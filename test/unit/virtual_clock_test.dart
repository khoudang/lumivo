import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';

void main() {
  group('VirtualClock Unit Tests', () {
    test('initializes with default or specified initial time and multiplier',
        () {
      final baseTime = DateTime(2026, 10, 20, 8, 0, 0);
      final clock = VirtualClock(
        initialTime: baseTime,
        initialMultiplier: 10.0,
      );

      expect(clock.now, baseTime);
      expect(clock.timeMultiplier, 10.0);
      expect(clock.isRunning, isFalse);

      clock.dispose();
    });

    test('advance() moves time forward deterministically', () {
      final baseTime = DateTime(2026, 10, 20, 10, 0, 0);
      final clock = VirtualClock(initialTime: baseTime);

      clock.advance(const Duration(minutes: 15));
      expect(clock.now, DateTime(2026, 10, 20, 10, 15, 0));

      clock.advance(const Duration(hours: 2, seconds: 30));
      expect(clock.now, DateTime(2026, 10, 20, 12, 15, 30));

      clock.dispose();
    });

    test(
        'setMultiplier() updates speed multiplier correctly and handles edge cases',
        () {
      final clock = VirtualClock();
      expect(clock.timeMultiplier, 1.0);

      clock.setMultiplier(60.0);
      expect(clock.timeMultiplier, 60.0);

      clock.setMultiplier(300.0);
      expect(clock.timeMultiplier, 300.0);

      clock.setMultiplier(-5.0);
      expect(clock.timeMultiplier, 0.0);

      clock.dispose();
    });

    test('setTime() updates time and emits to tickStream', () async {
      final baseTime = DateTime(2026, 10, 20, 6, 0, 0);
      final targetTime = DateTime(2026, 10, 20, 18, 30, 0);
      final clock = VirtualClock(initialTime: baseTime);

      final ticks = <DateTime>[];
      final sub = clock.tickStream.listen(ticks.add);

      clock.setTime(targetTime);
      await Future<void>.delayed(Duration.zero);

      expect(clock.now, targetTime);
      expect(ticks, [targetTime]);

      await sub.cancel();
      clock.dispose();
    });

    test('tickStream emits on each advance() call', () async {
      final baseTime = DateTime(2026, 10, 20, 12, 0, 0);
      final clock = VirtualClock(initialTime: baseTime);

      final ticks = <DateTime>[];
      final sub = clock.tickStream.listen(ticks.add);

      clock.advance(const Duration(seconds: 10));
      clock.advance(const Duration(seconds: 20));
      clock.advance(const Duration(minutes: 1));

      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 3);
      expect(ticks[0], DateTime(2026, 10, 20, 12, 0, 10));
      expect(ticks[1], DateTime(2026, 10, 20, 12, 0, 30));
      expect(ticks[2], DateTime(2026, 10, 20, 12, 1, 30));

      await sub.cancel();
      clock.dispose();
    });

    test('start() and stop() control timer lifecycle and periodic advancement',
        () async {
      final baseTime = DateTime(2026, 10, 20, 0, 0, 0);
      // Use short realTickInterval for quick async testing
      final clock = VirtualClock(
        initialTime: baseTime,
        initialMultiplier: 60.0, // 1 real sec = 60 virtual secs (1 min)
        realTickInterval: const Duration(milliseconds: 50),
      );

      expect(clock.isRunning, isFalse);
      clock.start();
      expect(clock.isRunning, isTrue);

      // Wait 120ms (approx 2 ticks)
      await Future<void>.delayed(const Duration(milliseconds: 130));

      clock.stop();
      expect(clock.isRunning, isFalse);

      final elapsedVirtual = clock.now.difference(baseTime);
      // 2 ticks * (50ms * 60 = 3000ms = 3s virtual per tick) = ~6s
      expect(elapsedVirtual.inMilliseconds, greaterThanOrEqualTo(5000));

      final stoppedTime = clock.now;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Time should not advance while stopped
      expect(clock.now, stoppedTime);

      clock.dispose();
    });
  });
}
