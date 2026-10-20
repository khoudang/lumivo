enum EnergyPeriod { day, week, month }

class EnergySample {
  const EnergySample({
    required this.timestamp,
    required this.powerWatts,
    required this.energyKWh,
    this.deviceId,
    this.estimatedCost = 0.0,
  });

  final DateTime timestamp;
  final double powerWatts;
  final double energyKWh;
  final String? deviceId;
  final double estimatedCost;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'powerWatts': powerWatts,
        'energyKWh': energyKWh,
        'deviceId': deviceId,
        'estimatedCost': estimatedCost,
      };

  factory EnergySample.fromJson(Map<String, dynamic> json) => EnergySample(
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        powerWatts: (json['powerWatts'] as num?)?.toDouble() ?? 0.0,
        energyKWh: (json['energyKWh'] as num?)?.toDouble() ?? 0.0,
        deviceId: json['deviceId'] as String?,
        estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      );
}

class EnergySummary {
  const EnergySummary({
    required this.period,
    required this.totalKWh,
    required this.totalCost,
    required this.averageWatts,
    required this.peakWatts,
    required this.samples,
    this.deviceBreakdown = const {},
    this.tariffRate = 0.16,
    this.currency = 'USD',
  });

  final EnergyPeriod period;
  final double totalKWh;
  final double totalCost;
  final double averageWatts;
  final double peakWatts;
  final List<EnergySample> samples;
  final Map<String, double> deviceBreakdown; // deviceId -> kWh
  final double tariffRate;
  final String currency;

  Map<String, dynamic> toJson() => {
        'period': period.name,
        'totalKWh': totalKWh,
        'totalCost': totalCost,
        'averageWatts': averageWatts,
        'peakWatts': peakWatts,
        'samples': samples.map((s) => s.toJson()).toList(),
        'deviceBreakdown': deviceBreakdown,
        'tariffRate': tariffRate,
        'currency': currency,
      };

  factory EnergySummary.fromJson(Map<String, dynamic> json) => EnergySummary(
        period: EnergyPeriod.values.firstWhere(
          (e) => e.name == json['period'],
          orElse: () => EnergyPeriod.day,
        ),
        totalKWh: (json['totalKWh'] as num?)?.toDouble() ?? 0.0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
        averageWatts: (json['averageWatts'] as num?)?.toDouble() ?? 0.0,
        peakWatts: (json['peakWatts'] as num?)?.toDouble() ?? 0.0,
        samples: (json['samples'] as List<dynamic>?)
                ?.map((e) => EnergySample.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        deviceBreakdown: json['deviceBreakdown'] is Map
            ? (json['deviceBreakdown'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              )
            : const {},
        tariffRate: (json['tariffRate'] as num?)?.toDouble() ?? 0.16,
        currency: json['currency'] as String? ?? 'USD',
      );
}
