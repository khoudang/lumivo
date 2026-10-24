class EnergyBreakdownItem {
  const EnergyBreakdownItem({
    required this.id,
    required this.name,
    required this.category,
    required this.wattage,
    required this.kwh,
    required this.cost,
  });

  final String id;
  final String name;
  final String category; // 'device' or 'room'
  final double wattage;
  final double kwh;
  final double cost;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'wattage': wattage,
        'kwh': kwh,
        'cost': cost,
      };

  factory EnergyBreakdownItem.fromJson(Map<String, dynamic> json) =>
      EnergyBreakdownItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'device',
        wattage: (json['wattage'] as num?)?.toDouble() ?? 0.0,
        kwh: (json['kwh'] as num?)?.toDouble() ?? 0.0,
        cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      );
}

class EnergyReport {
  const EnergyReport({
    required this.period, // 'day', 'week', 'month'
    required this.totalKwh,
    required this.totalCost,
    required this.tariff,
    required this.previousPeriodKwh,
    required this.percentChange,
    required this.deviceBreakdown,
    required this.roomBreakdown,
    required this.generatedAt,
  });

  final String period;
  final double totalKwh;
  final double totalCost;
  final double tariff;
  final double previousPeriodKwh;
  final double percentChange;
  final List<EnergyBreakdownItem> deviceBreakdown;
  final List<EnergyBreakdownItem> roomBreakdown;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'period': period,
        'totalKwh': totalKwh,
        'totalCost': totalCost,
        'tariff': tariff,
        'previousPeriodKwh': previousPeriodKwh,
        'percentChange': percentChange,
        'deviceBreakdown': deviceBreakdown.map((e) => e.toJson()).toList(),
        'roomBreakdown': roomBreakdown.map((e) => e.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}
