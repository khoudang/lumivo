import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/energy_sample.dart';

/// Abstract interface for real-time energy telemetry aggregator and analytics.
abstract interface class EnergyAnalyticsService {
  factory EnergyAnalyticsService({
    double defaultTariffRate,
    String defaultCurrency,
  }) = DefaultEnergyAnalyticsService;

  /// Active default tariff rate per kWh.
  double get tariffRate;

  /// Aggregated per-device energy consumption breakdown (deviceId -> total kWh).
  Map<String, double> get deviceBreakdown;

  /// All recorded energy telemetry samples.
  List<EnergySample> get samples;

  /// Records a real-time energy sample derived from active device wattage and virtual time.
  ///
  /// Energy formula: `kWh = (powerWatts * elapsedVirtualHours) / 1000.0`.
  /// Cost formula: `estimatedCost = kWh * tariffRate`.
  void recordSample({
    required DateTime timestamp,
    required double powerWatts,
    required Duration elapsedDuration,
    Map<String, double>? perDeviceWatts,
    double tariffRate = 0.16,
  });

  /// Computes and returns an aggregated [EnergySummary] for the requested [EnergyPeriod].
  EnergySummary getSummary(
    EnergyPeriod period, {
    double tariffRate = 0.16,
    String currency = 'USD',
  });

  /// Subscribes to rolling summary updates for the given [EnergyPeriod].
  Stream<EnergySummary> watchSummary(EnergyPeriod period);

  /// Sets the base tariff rate ($/kWh).
  void setTariffRate(double rate);

  /// Seeds realistic historical daily energy samples for the past 30 days.
  ///
  /// Ensures charts, gauges, and summaries have valid simulated data on first launch.
  void seedHistoricalSamples({
    DateTime? anchorTime,
    double tariffRate = 0.16,
  });

  /// Disposes internal streams and resources.
  void dispose();
}

/// Concrete implementation of [EnergyAnalyticsService].
class DefaultEnergyAnalyticsService implements EnergyAnalyticsService {
  DefaultEnergyAnalyticsService({
    double defaultTariffRate = 0.16,
    String defaultCurrency = 'USD',
  })  : _tariffRate = defaultTariffRate,
        _currency = defaultCurrency {
    for (final period in EnergyPeriod.values) {
      _controllers[period] = StreamController<EnergySummary>.broadcast();
    }
  }

  double _tariffRate;
  bool _customTariffSet = false;
  final String _currency;

  final List<EnergySample> _samples = [];
  final List<EnergySample> _deviceSamples = [];
  final Map<String, double> _deviceBreakdown = {};

  final Map<EnergyPeriod, StreamController<EnergySummary>> _controllers = {};

  @override
  double get tariffRate => _tariffRate;

  @override
  Map<String, double> get deviceBreakdown => Map.unmodifiable(_deviceBreakdown);

  @override
  List<EnergySample> get samples => List.unmodifiable(_samples);

  @override
  void setTariffRate(double rate) {
    _tariffRate = rate;
    _customTariffSet = true;
    _notifySubscribers();
  }

  @override
  void recordSample({
    required DateTime timestamp,
    required double powerWatts,
    required Duration elapsedDuration,
    Map<String, double>? perDeviceWatts,
    double tariffRate = 0.16,
  }) {
    final effectiveTariff =
        (_customTariffSet && tariffRate == 0.16) ? _tariffRate : tariffRate;

    final elapsedVirtualHours =
        elapsedDuration.inMicroseconds / Duration.microsecondsPerHour;
    final kwh = (powerWatts * elapsedVirtualHours) / 1000.0;
    final estimatedCost = kwh * effectiveTariff;

    final sample = EnergySample(
      timestamp: timestamp,
      powerWatts: powerWatts,
      energyKWh: kwh,
      estimatedCost: estimatedCost,
    );
    _samples.add(sample);

    if (perDeviceWatts != null) {
      for (final entry in perDeviceWatts.entries) {
        final devWatts = entry.value;
        final devKwh = (devWatts * elapsedVirtualHours) / 1000.0;
        final devCost = devKwh * effectiveTariff;

        _deviceBreakdown[entry.key] =
            (_deviceBreakdown[entry.key] ?? 0.0) + devKwh;

        _deviceSamples.add(EnergySample(
          timestamp: timestamp,
          powerWatts: devWatts,
          energyKWh: devKwh,
          deviceId: entry.key,
          estimatedCost: devCost,
        ));
      }
    }

    _pruneOldSamples();
    _notifySubscribers();
  }

  @override
  EnergySummary getSummary(
    EnergyPeriod period, {
    double tariffRate = 0.16,
    String currency = 'USD',
  }) {
    final effectiveTariff =
        (_customTariffSet && tariffRate == 0.16) ? _tariffRate : tariffRate;
    final effectiveCurrency = currency.isNotEmpty ? currency : _currency;

    if (_samples.isEmpty) {
      return EnergySummary(
        period: period,
        totalKWh: 0.0,
        totalCost: 0.0,
        averageWatts: 0.0,
        peakWatts: 0.0,
        samples: const [],
        deviceBreakdown: const {},
        tariffRate: effectiveTariff,
        currency: effectiveCurrency,
      );
    }

    final anchor = _getLatestSampleTimestamp();
    final windowDuration = _durationForPeriod(period);
    final cutoff = anchor.subtract(windowDuration);

    final matchedSamples = _samples.where((s) {
      return s.timestamp.isAfter(cutoff) &&
          (s.timestamp.isBefore(anchor) ||
              s.timestamp.isAtSameMomentAs(anchor));
    }).toList();

    double totalKWh = 0.0;
    double totalWatts = 0.0;
    double peakWatts = 0.0;

    for (final s in matchedSamples) {
      totalKWh += s.energyKWh;
      totalWatts += s.powerWatts;
      if (s.powerWatts > peakWatts) {
        peakWatts = s.powerWatts;
      }
    }

    final averageWatts =
        matchedSamples.isEmpty ? 0.0 : totalWatts / matchedSamples.length;
    final totalCost = totalKWh * effectiveTariff;

    // Period-specific device breakdown
    final periodDeviceBreakdown = <String, double>{};
    for (final ds in _deviceSamples) {
      if (ds.timestamp.isAfter(cutoff) &&
          (ds.timestamp.isBefore(anchor) ||
              ds.timestamp.isAtSameMomentAs(anchor))) {
        if (ds.deviceId != null) {
          periodDeviceBreakdown[ds.deviceId!] =
              (periodDeviceBreakdown[ds.deviceId!] ?? 0.0) + ds.energyKWh;
        }
      }
    }

    final breakdown = periodDeviceBreakdown.isNotEmpty
        ? periodDeviceBreakdown
        : Map<String, double>.from(_deviceBreakdown);

    return EnergySummary(
      period: period,
      totalKWh: totalKWh,
      totalCost: totalCost,
      averageWatts: averageWatts,
      peakWatts: peakWatts,
      samples: List.unmodifiable(matchedSamples),
      deviceBreakdown: Map.unmodifiable(breakdown),
      tariffRate: effectiveTariff,
      currency: effectiveCurrency,
    );
  }

  @override
  Stream<EnergySummary> watchSummary(EnergyPeriod period) async* {
    yield getSummary(period);
    final controller = _controllers[period];
    if (controller != null) {
      yield* controller.stream;
    }
  }

  @override
  void seedHistoricalSamples({
    DateTime? anchorTime,
    double tariffRate = 0.16,
  }) {
    _samples.clear();
    _deviceSamples.clear();
    _deviceBreakdown.clear();

    final effectiveTariff =
        (_customTariffSet && tariffRate == 0.16) ? _tariffRate : tariffRate;
    final anchor = anchorTime ?? DateTime.now();
    final normalizedAnchor =
        DateTime(anchor.year, anchor.month, anchor.day, 12, 0);

    for (int i = 29; i >= 0; i--) {
      final sampleTime = normalizedAnchor.subtract(Duration(days: i));
      final variance = ((i * 37 + 13) % 250).toDouble();
      final dailyWatts = 550.0 + variance;
      const elapsedHours = 24.0;
      final dailyKWh = (dailyWatts * elapsedHours) / 1000.0;
      final cost = dailyKWh * effectiveTariff;

      final sample = EnergySample(
        timestamp: sampleTime,
        powerWatts: dailyWatts,
        energyKWh: dailyKWh,
        estimatedCost: cost,
      );
      _samples.add(sample);

      final devWatts = {
        'device-ac-1': dailyWatts * 0.50,
        'device-socket-1': dailyWatts * 0.25,
        'device-bulb-1': dailyWatts * 0.15,
        'device-fan-1': dailyWatts * 0.10,
      };

      for (final entry in devWatts.entries) {
        final devKWh = (entry.value * elapsedHours) / 1000.0;
        final devCost = devKWh * effectiveTariff;
        _deviceSamples.add(EnergySample(
          timestamp: sampleTime,
          powerWatts: entry.value,
          energyKWh: devKWh,
          deviceId: entry.key,
          estimatedCost: devCost,
        ));
        _deviceBreakdown[entry.key] =
            (_deviceBreakdown[entry.key] ?? 0.0) + devKWh;
      }
    }

    _notifySubscribers();
  }

  DateTime _getLatestSampleTimestamp() {
    if (_samples.isEmpty) return DateTime.now();
    var latest = _samples.first.timestamp;
    for (final s in _samples) {
      if (s.timestamp.isAfter(latest)) {
        latest = s.timestamp;
      }
    }
    return latest;
  }

  Duration _durationForPeriod(EnergyPeriod period) {
    switch (period) {
      case EnergyPeriod.day:
        return const Duration(hours: 24);
      case EnergyPeriod.week:
        return const Duration(days: 7);
      case EnergyPeriod.month:
        return const Duration(days: 30);
    }
  }

  static const int maxStoredSamples = 5000;
  static const int maxStoredDeviceSamples = 10000;

  void _pruneOldSamples() {
    if (_samples.isEmpty) return;
    final latest = _getLatestSampleTimestamp();
    final pruneCutoff = latest.subtract(const Duration(days: 35));
    _samples.removeWhere((s) => s.timestamp.isBefore(pruneCutoff));
    _deviceSamples.removeWhere((s) => s.timestamp.isBefore(pruneCutoff));

    if (_samples.length > maxStoredSamples) {
      _samples.removeRange(0, _samples.length - maxStoredSamples);
    }
    if (_deviceSamples.length > maxStoredDeviceSamples) {
      _deviceSamples.removeRange(
          0, _deviceSamples.length - maxStoredDeviceSamples);
    }
  }

  void _notifySubscribers() {
    for (final period in EnergyPeriod.values) {
      final controller = _controllers[period];
      if (controller != null &&
          !controller.isClosed &&
          controller.hasListener) {
        controller.add(getSummary(period));
      }
    }
  }

  @override
  void dispose() {
    _samples.clear();
    _deviceSamples.clear();
    _deviceBreakdown.clear();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}

/// Riverpod provider for [EnergyAnalyticsService].
final energyAnalyticsServiceProvider = Provider<EnergyAnalyticsService>((ref) {
  final service = DefaultEnergyAnalyticsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Riverpod stream provider family for [EnergySummary].
final energySummaryProvider =
    StreamProvider.family<EnergySummary, EnergyPeriod>((ref, period) {
  final service = ref.watch(energyAnalyticsServiceProvider);
  return service.watchSummary(period);
});
