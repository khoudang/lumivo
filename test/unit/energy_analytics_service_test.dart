import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/energy_sample.dart';
import 'package:lumivo/services/energy/energy_analytics_service.dart';

void main() {
  group('EnergyAnalyticsService Unit Tests', () {
    late EnergyAnalyticsService service;

    setUp(() {
      service = EnergyAnalyticsService();
    });

    tearDown(() {
      service.dispose();
    });

    test(
        'Exact wattage x time math: 1000W for 1 virtual hour = exactly 1.0 kWh',
        () {
      final timestamp = DateTime(2026, 6, 1, 12, 0);

      service.recordSample(
        timestamp: timestamp,
        powerWatts: 1000.0,
        elapsedDuration: const Duration(hours: 1),
      );

      final summary = service.getSummary(EnergyPeriod.day);
      expect(summary.totalKWh, equals(1.0));
      expect(summary.samples.length, equals(1));
      expect(summary.samples.first.powerWatts, equals(1000.0));
      expect(summary.averageWatts, equals(1000.0));
      expect(summary.peakWatts, equals(1000.0));
    });

    test('Tariff cost calculation: 1.0 kWh at \$0.16 = \$0.16', () {
      final timestamp = DateTime(2026, 6, 1, 12, 0);

      service.recordSample(
        timestamp: timestamp,
        powerWatts: 1000.0,
        elapsedDuration: const Duration(hours: 1),
        tariffRate: 0.16,
      );

      final summary = service.getSummary(EnergyPeriod.day, tariffRate: 0.16);
      expect(summary.totalCost, equals(0.16));
    });

    test('setTariffRate updates active tariff and cost calculation', () {
      service.setTariffRate(0.25);
      expect(service.tariffRate, equals(0.25));

      service.recordSample(
        timestamp: DateTime(2026, 6, 1, 12, 0),
        powerWatts: 2000.0,
        elapsedDuration: const Duration(hours: 1), // 2.0 kWh
      );

      final summary = service.getSummary(EnergyPeriod.day);
      expect(summary.totalKWh, equals(2.0));
      expect(summary.totalCost, equals(0.50)); // 2.0 * 0.25 = $0.50
    });

    test('Daily, weekly, and monthly aggregation', () {
      final anchor = DateTime(2026, 7, 20, 12, 0);

      // Sample 1: Today (2 hours ago) -> in Day, Week, Month
      service.recordSample(
        timestamp: anchor.subtract(const Duration(hours: 2)),
        powerWatts: 1000.0,
        elapsedDuration: const Duration(hours: 1), // 1.0 kWh
      );

      // Sample 2: 3 days ago -> in Week, Month (NOT in Day)
      service.recordSample(
        timestamp: anchor.subtract(const Duration(days: 3)),
        powerWatts: 2000.0,
        elapsedDuration: const Duration(hours: 1), // 2.0 kWh
      );

      // Sample 3: 15 days ago -> in Month (NOT in Day, NOT in Week)
      service.recordSample(
        timestamp: anchor.subtract(const Duration(days: 15)),
        powerWatts: 3000.0,
        elapsedDuration: const Duration(hours: 1), // 3.0 kWh
      );

      final daySummary = service.getSummary(EnergyPeriod.day);
      expect(daySummary.samples.length, equals(1));
      expect(daySummary.totalKWh, equals(1.0));

      final weekSummary = service.getSummary(EnergyPeriod.week);
      expect(weekSummary.samples.length, equals(2));
      expect(weekSummary.totalKWh, equals(3.0)); // 1.0 + 2.0

      final monthSummary = service.getSummary(EnergyPeriod.month);
      expect(monthSummary.samples.length, equals(3));
      expect(monthSummary.totalKWh, equals(6.0)); // 1.0 + 2.0 + 3.0

      // Verify hierarchical progression
      expect(daySummary.totalKWh < weekSummary.totalKWh, isTrue);
      expect(weekSummary.totalKWh < monthSummary.totalKWh, isTrue);
    });

    test('Per-device wattage breakdown', () {
      final timestamp = DateTime(2026, 6, 1, 12, 0);

      service.recordSample(
        timestamp: timestamp,
        powerWatts: 1000.0,
        elapsedDuration: const Duration(hours: 2), // 2 hours
        perDeviceWatts: {
          'device-ac-1': 700.0,
          'device-bulb-1': 300.0,
        },
      );

      // Total kWh = 1000W * 2h / 1000 = 2.0 kWh
      // AC = 700W * 2h / 1000 = 1.4 kWh
      // Bulb = 300W * 2h / 1000 = 0.6 kWh
      final summary = service.getSummary(EnergyPeriod.day);
      expect(summary.totalKWh, equals(2.0));
      expect(summary.deviceBreakdown['device-ac-1'], equals(1.4));
      expect(summary.deviceBreakdown['device-bulb-1'], equals(0.6));

      // Global service breakdown
      expect(service.deviceBreakdown['device-ac-1'], equals(1.4));
      expect(service.deviceBreakdown['device-bulb-1'], equals(0.6));
    });

    test('seedHistoricalSamples produces valid 30-day samples', () {
      final anchor = DateTime(2026, 8, 1, 12, 0);
      service.seedHistoricalSamples(anchorTime: anchor, tariffRate: 0.16);

      // Verify exact count of 30 daily samples
      expect(service.samples.length, equals(30));

      // Every sample must have valid positive values
      for (final s in service.samples) {
        expect(s.powerWatts, greaterThan(0));
        expect(s.energyKWh, greaterThan(0));
        expect(s.estimatedCost, greaterThan(0));
      }

      // Verify per-device breakdown is populated
      expect(service.deviceBreakdown.containsKey('device-ac-1'), isTrue);
      expect(service.deviceBreakdown.containsKey('device-socket-1'), isTrue);
      expect(service.deviceBreakdown.containsKey('device-bulb-1'), isTrue);
      expect(service.deviceBreakdown.containsKey('device-fan-1'), isTrue);

      final month = service.getSummary(EnergyPeriod.month);
      expect(month.samples.length, equals(30));
      expect(month.totalKWh, greaterThan(0));
      expect(month.totalCost, greaterThan(0));
      expect(month.averageWatts, greaterThan(0));
      expect(month.peakWatts, greaterThan(0));

      final week = service.getSummary(EnergyPeriod.week);
      expect(week.samples.length, equals(7));
      expect(week.totalKWh, lessThan(month.totalKWh));

      final day = service.getSummary(EnergyPeriod.day);
      expect(day.samples.length, equals(1));
      expect(day.totalKWh, lessThan(week.totalKWh));
    });

    test('watchSummary emits initial summary and updates on new samples',
        () async {
      final emitted = <EnergySummary>[];
      final sub = service.watchSummary(EnergyPeriod.day).listen(emitted.add);

      await pumpEventQueue();
      expect(emitted.length, equals(1));
      expect(emitted.first.totalKWh, equals(0.0));

      service.recordSample(
        timestamp: DateTime(2026, 6, 1, 12, 0),
        powerWatts: 1500.0,
        elapsedDuration: const Duration(hours: 1),
      );

      await pumpEventQueue();
      expect(emitted.length, equals(2));
      expect(emitted.last.totalKWh, equals(1.5));

      await sub.cancel();
    });

    test('Empty service returns zeroed EnergySummary', () {
      final summary = service.getSummary(EnergyPeriod.month);
      expect(summary.totalKWh, equals(0.0));
      expect(summary.totalCost, equals(0.0));
      expect(summary.averageWatts, equals(0.0));
      expect(summary.peakWatts, equals(0.0));
      expect(summary.samples.isEmpty, isTrue);
      expect(summary.deviceBreakdown.isEmpty, isTrue);
    });
  });
}
