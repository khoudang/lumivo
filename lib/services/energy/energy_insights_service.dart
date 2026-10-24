import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/energy_report.dart';
import '../../core/models/smart_device.dart';

/// Service responsible for energy analytics calculation, period reporting,
/// and CSV telemetry export.
class EnergyInsightsService {
  const EnergyInsightsService({this.defaultTariff = 0.15});

  /// Default electricity tariff rate in USD ($/kWh).
  final double defaultTariff;

  /// Returns elapsed virtual hours for standard reporting periods.
  /// - `'day'`: 24.0 hours
  /// - `'week'`: 168.0 hours (7 * 24h)
  /// - `'month'`: 720.0 hours (30 * 24h)
  static double hoursForPeriod(String period) {
    switch (period.trim().toLowerCase()) {
      case 'week':
        return 168.0;
      case 'month':
        return 720.0;
      case 'day':
      default:
        return 24.0;
    }
  }

  /// Calculates energy consumption in kilowatt-hours (kWh).
  /// Formula: `(powerWatts * virtualHours) / 1000.0`.
  static double calculateKwh(double watts, double hours) {
    if (watts <= 0.0 || hours <= 0.0) return 0.0;
    return (watts * hours) / 1000.0;
  }

  /// Calculates estimated cost based on energy consumption and tariff.
  /// Formula: `kwh * tariff`.
  static double calculateCost(double kwh, double tariff) {
    if (kwh <= 0.0 || tariff <= 0.0) return 0.0;
    return kwh * tariff;
  }

  /// Calculates percentage change between current and previous consumption.
  /// Formula: `((currentKwh - previousKwh) / previousKwh) * 100.0`.
  static double calculatePercentChange(double currentKwh, double previousKwh) {
    if (previousKwh <= 0.0) {
      return currentKwh > 0.0 ? 100.0 : 0.0;
    }
    return ((currentKwh - previousKwh) / previousKwh) * 100.0;
  }

  /// Generates a comprehensive [EnergyReport] for [devices] across [period].
  ///
  /// Can be scoped to a specific [homeId].
  /// If [previousPeriodKwh] is provided, uses it for comparison;
  /// otherwise estimates a plausible previous period benchmark.
  EnergyReport generateReport({
    required List<SmartDevice> devices,
    String period = 'day',
    double? tariff,
    double? previousPeriodKwh,
    String? homeId,
    DateTime? generatedAt,
  }) {
    final effectiveTariff = tariff ?? defaultTariff;
    final hours = hoursForPeriod(period);
    final timestamp = generatedAt ?? DateTime.now();

    final scopedDevices = homeId != null
        ? devices.where((d) => d.homeId == homeId).toList()
        : devices;

    // 1. Per-device breakdown
    final deviceItems = <EnergyBreakdownItem>[];
    for (final device in scopedDevices) {
      final watts = device.isOn ? device.powerUsageWatts : 0.0;
      final kwh = calculateKwh(watts, hours);
      final cost = calculateCost(kwh, effectiveTariff);

      deviceItems.add(
        EnergyBreakdownItem(
          id: device.id,
          name: device.name,
          category: 'device',
          wattage: double.parse(watts.toStringAsFixed(2)),
          kwh: double.parse(kwh.toStringAsFixed(4)),
          cost: double.parse(cost.toStringAsFixed(4)),
        ),
      );
    }

    // Sort device items: descending kWh, then alphabetical name
    deviceItems.sort((a, b) {
      final comp = b.kwh.compareTo(a.kwh);
      if (comp != 0) return comp;
      return a.name.compareTo(b.name);
    });

    // 2. Per-room breakdown
    final roomMap = <String, ({double watts, double kwh, double cost})>{};
    for (final device in scopedDevices) {
      final roomId = device.roomId;
      final watts = device.isOn ? device.powerUsageWatts : 0.0;
      final kwh = calculateKwh(watts, hours);
      final cost = calculateCost(kwh, effectiveTariff);

      final current = roomMap[roomId] ?? (watts: 0.0, kwh: 0.0, cost: 0.0);
      roomMap[roomId] = (
        watts: current.watts + watts,
        kwh: current.kwh + kwh,
        cost: current.cost + cost,
      );
    }

    final roomItems = roomMap.entries.map((entry) {
      return EnergyBreakdownItem(
        id: entry.key,
        name: entry.key,
        category: 'room',
        wattage: double.parse(entry.value.watts.toStringAsFixed(2)),
        kwh: double.parse(entry.value.kwh.toStringAsFixed(4)),
        cost: double.parse(entry.value.cost.toStringAsFixed(4)),
      );
    }).toList();

    // Sort room items: descending kWh, then alphabetical name
    roomItems.sort((a, b) {
      final comp = b.kwh.compareTo(a.kwh);
      if (comp != 0) return comp;
      return a.name.compareTo(b.name);
    });

    // 3. Totals and comparison
    final totalKwhRaw =
        deviceItems.fold<double>(0.0, (acc, item) => acc + item.kwh);
    final totalKwh = double.parse(totalKwhRaw.toStringAsFixed(4));

    final totalCostRaw = totalKwh * effectiveTariff;
    final totalCost = double.parse(totalCostRaw.toStringAsFixed(4));

    final effectivePrevKwh = previousPeriodKwh ?? (totalKwh * 0.95);
    final pctChangeRaw = calculatePercentChange(totalKwh, effectivePrevKwh);
    final percentChange = double.parse(pctChangeRaw.toStringAsFixed(2));

    return EnergyReport(
      period: period.trim().toLowerCase(),
      totalKwh: totalKwh,
      totalCost: totalCost,
      tariff: effectiveTariff,
      previousPeriodKwh: double.parse(effectivePrevKwh.toStringAsFixed(4)),
      percentChange: percentChange,
      deviceBreakdown: deviceItems,
      roomBreakdown: roomItems,
      generatedAt: timestamp,
    );
  }

  /// Exports an [EnergyReport] as a standard RFC-4180 CSV document.
  ///
  /// Headers: `Period,Category,Name,Wattage_W,Consumption_kWh,Estimated_Cost,Tariff`
  /// Includes timestamp and notice that all figures are simulated estimates.
  String exportEnergyCsv(EnergyReport report) {
    final buffer = StringBuffer();

    // Metadata lines with timestamp and simulated estimates notice
    buffer.writeln(
        '# Lumivo Energy Report - Generated: ${report.generatedAt.toIso8601String()}');
    buffer.writeln('# Notice: All figures are simulated estimates.');

    // CSV header row
    buffer.writeln(
        'Period,Category,Name,Wattage_W,Consumption_kWh,Estimated_Cost,Tariff');

    String escapeCsv(String value) {
      if (value.contains(',') || value.contains('"') || value.contains('\n')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }

    // Per-device rows
    for (final item in report.deviceBreakdown) {
      buffer.writeln([
        escapeCsv(report.period),
        escapeCsv(item.category),
        escapeCsv(item.name),
        item.wattage.toStringAsFixed(2),
        item.kwh.toStringAsFixed(4),
        item.cost.toStringAsFixed(4),
        report.tariff.toStringAsFixed(4),
      ].join(','));
    }

    // Per-room rows
    for (final item in report.roomBreakdown) {
      buffer.writeln([
        escapeCsv(report.period),
        escapeCsv(item.category),
        escapeCsv(item.name),
        item.wattage.toStringAsFixed(2),
        item.kwh.toStringAsFixed(4),
        item.cost.toStringAsFixed(4),
        report.tariff.toStringAsFixed(4),
      ].join(','));
    }

    return buffer.toString();
  }
}

/// Riverpod provider for [EnergyInsightsService].
final energyInsightsServiceProvider = Provider<EnergyInsightsService>((ref) {
  return const EnergyInsightsService();
});
