enum DeviceHealthStatus {
  healthy,
  degraded,
  offline,
  warning,
}

class DeviceHealth {
  const DeviceHealth({
    required this.deviceId,
    required this.status,
    required this.rssi,
    required this.batteryLevel,
    required this.isOnline,
    required this.lastSeen,
    this.failureCount = 0,
    this.statusMessage = 'Normal',
    this.homeId = 'home-default',
  });

  final String deviceId;
  final DeviceHealthStatus status;
  final int rssi;
  final int? batteryLevel;
  final bool isOnline;
  final DateTime lastSeen;
  final int failureCount;
  final String statusMessage;
  final String homeId;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'status': status.name,
        'rssi': rssi,
        'batteryLevel': batteryLevel,
        'isOnline': isOnline,
        'lastSeen': lastSeen.toIso8601String(),
        'failureCount': failureCount,
        'statusMessage': statusMessage,
        'homeId': homeId,
      };

  factory DeviceHealth.fromJson(Map<String, dynamic> json) => DeviceHealth(
        deviceId: json['deviceId'] as String? ?? '',
        status: DeviceHealthStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => DeviceHealthStatus.healthy,
        ),
        rssi: json['rssi'] as int? ?? -60,
        batteryLevel: json['batteryLevel'] as int?,
        isOnline: json['isOnline'] as bool? ?? true,
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse(json['lastSeen'] as String) ?? DateTime.now()
            : DateTime.now(),
        failureCount: json['failureCount'] as int? ?? 0,
        statusMessage: json['statusMessage'] as String? ?? 'Normal',
        homeId: json['homeId'] as String? ?? 'home-default',
      );
}

class HomeHealthSummary {
  const HomeHealthSummary({
    required this.homeId,
    required this.totalDevices,
    required this.onlineDevices,
    required this.offlineDevices,
    required this.degradedDevices,
    required this.healthScore,
    required this.warnings,
  });

  final String homeId;
  final int totalDevices;
  final int onlineDevices;
  final int offlineDevices;
  final int degradedDevices;
  final int healthScore; // 0 - 100
  final List<String> warnings;
}
