import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart' show devicesProvider;
import '../../../core/models/energy_report.dart';
import '../../../core/models/room.dart';
import '../../../core/models/smart_device.dart';
import '../../home/state/homes_notifier.dart';
import '../../rooms/state/rooms_notifier.dart';

class EnergyInsightsEngine {
  const EnergyInsightsEngine._();

  static double getHoursForPeriod(String period) {
    switch (period.toLowerCase()) {
      case 'week':
        return 168.0;
      case 'month':
        return 720.0;
      case 'day':
      default:
        return 24.0;
    }
  }

  static EnergyReport computeReport({
    required String period,
    required List<SmartDevice> devices,
    required List<Room> rooms,
    required double tariff,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final hours = getHoursForPeriod(period);

    final deviceItems = <EnergyBreakdownItem>[];
    double totalKwh = 0.0;
    double totalCost = 0.0;

    for (final dev in devices) {
      final wattage = dev.isOn ? dev.powerUsageWatts : 0.0;
      final kwh = double.parse(((wattage * hours) / 1000.0).toStringAsFixed(4));
      final cost = double.parse((kwh * tariff).toStringAsFixed(4));

      totalKwh += kwh;
      totalCost += cost;

      deviceItems.add(
        EnergyBreakdownItem(
          id: dev.id,
          name: dev.name,
          category: 'device',
          wattage: wattage,
          kwh: kwh,
          cost: cost,
        ),
      );
    }

    final roomItems = <EnergyBreakdownItem>[];
    for (final room in rooms) {
      final roomDevices = devices
          .where((d) => d.roomId == room.id || d.roomId == room.name)
          .toList();

      double roomWattage = 0.0;
      double roomKwh = 0.0;
      double roomCost = 0.0;

      for (final dev in roomDevices) {
        final w = dev.isOn ? dev.powerUsageWatts : 0.0;
        final k = double.parse(((w * hours) / 1000.0).toStringAsFixed(4));
        final c = double.parse((k * tariff).toStringAsFixed(4));
        roomWattage += w;
        roomKwh += k;
        roomCost += c;
      }

      roomItems.add(
        EnergyBreakdownItem(
          id: room.id,
          name: room.name,
          category: 'room',
          wattage: roomWattage,
          kwh: double.parse(roomKwh.toStringAsFixed(4)),
          cost: double.parse(roomCost.toStringAsFixed(4)),
        ),
      );
    }

    totalKwh = double.parse(totalKwh.toStringAsFixed(4));
    totalCost = double.parse(totalCost.toStringAsFixed(4));
    final previousPeriodKwh =
        double.parse((totalKwh * 0.95).toStringAsFixed(4));
    final percentChange = previousPeriodKwh > 0
        ? double.parse(
            (((totalKwh - previousPeriodKwh) / previousPeriodKwh) * 100)
                .toStringAsFixed(2),
          )
        : 0.0;

    return EnergyReport(
      period: period,
      totalKwh: totalKwh,
      totalCost: totalCost,
      tariff: tariff,
      previousPeriodKwh: previousPeriodKwh,
      percentChange: percentChange,
      deviceBreakdown: deviceItems,
      roomBreakdown: roomItems,
      generatedAt: now,
    );
  }

  static String exportToCsv(EnergyReport report) {
    final buffer = StringBuffer();
    buffer.writeln(
        'Timestamp,Category,ID,Name,Power (W),Energy (kWh),Cost (\$),Tariff (\$/kWh)');
    final ts = report.generatedAt.toIso8601String();

    String escapeCsv(String value) {
      return '"${value.replaceAll('"', '""')}"';
    }

    for (final item in report.deviceBreakdown) {
      buffer.writeln(
          '$ts,device,${item.id},${escapeCsv(item.name)},${item.wattage.toStringAsFixed(2)},${item.kwh.toStringAsFixed(4)},${item.cost.toStringAsFixed(4)},${report.tariff.toStringAsFixed(4)}');
    }

    for (final item in report.roomBreakdown) {
      buffer.writeln(
          '$ts,room,${item.id},${escapeCsv(item.name)},${item.wattage.toStringAsFixed(2)},${item.kwh.toStringAsFixed(4)},${item.cost.toStringAsFixed(4)},${report.tariff.toStringAsFixed(4)}');
    }

    buffer.writeln(
        '$ts,total,total,Total,0.00,${report.totalKwh.toStringAsFixed(4)},${report.totalCost.toStringAsFixed(4)},${report.tariff.toStringAsFixed(4)}');

    return buffer.toString();
  }
}

final energyPeriodProvider = StateProvider<String>((ref) => 'day');

final energyReportProvider = Provider<EnergyReport>((ref) {
  final period = ref.watch(energyPeriodProvider);
  final currentHome = ref.watch(currentHomeProvider);
  final devicesAsync = ref.watch(devicesProvider);
  final rooms = ref.watch(roomsProvider);

  final allDevices = devicesAsync.value ?? const [];
  final homeDevices =
      allDevices.where((d) => d.homeId == currentHome.id).toList();
  final homeRooms = rooms.where((r) => r.homeId == currentHome.id).toList();

  return EnergyInsightsEngine.computeReport(
    period: period,
    devices: homeDevices,
    rooms: homeRooms,
    tariff: currentHome.tariffRate,
  );
});
