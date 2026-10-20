enum DeviceType {
  light,
  fan,
  security,
  ac,
  socket,
  curtain,
  lock,
  sensor,
}

enum DeviceConnection { online, offline }

class SmartDevice {
  const SmartDevice({
    required this.id,
    required this.name,
    required this.roomId,
    required this.type,
    required this.isOn,
    this.brightness = 100,
    this.connection = DeviceConnection.online,
    this.targetTemperature = 24.0,
    this.currentTemperature = 25.0,
    this.currentHumidity = 55.0,
    this.position = 0,
    this.isLocked = true,
    this.powerUsageWatts = 0.0,
    this.customData = const {},
  });

  final String id;
  final String name;
  final String roomId;
  final DeviceType type;
  final bool isOn;
  final int brightness;
  final DeviceConnection connection;
  final double targetTemperature;
  final double currentTemperature;
  final double currentHumidity;
  final int position;
  final bool isLocked;
  final double powerUsageWatts;
  final Map<String, dynamic> customData;

  SmartDevice copyWith({
    bool? isOn,
    int? brightness,
    DeviceConnection? connection,
    double? targetTemperature,
    double? currentTemperature,
    double? currentHumidity,
    int? position,
    bool? isLocked,
    double? powerUsageWatts,
    String? name,
    String? roomId,
    DeviceType? type,
    Map<String, dynamic>? customData,
  }) =>
      SmartDevice(
        id: id,
        name: name ?? this.name,
        roomId: roomId ?? this.roomId,
        type: type ?? this.type,
        isOn: isOn ?? this.isOn,
        brightness: brightness ?? this.brightness,
        connection: connection ?? this.connection,
        targetTemperature: targetTemperature ?? this.targetTemperature,
        currentTemperature: currentTemperature ?? this.currentTemperature,
        currentHumidity: currentHumidity ?? this.currentHumidity,
        position: position ?? this.position,
        isLocked: isLocked ?? this.isLocked,
        powerUsageWatts: powerUsageWatts ?? this.powerUsageWatts,
        customData: customData ?? this.customData,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roomId': roomId,
        'type': type.name,
        'isOn': isOn,
        'brightness': brightness,
        'connection': connection.name,
        'targetTemperature': targetTemperature,
        'currentTemperature': currentTemperature,
        'currentHumidity': currentHumidity,
        'position': position,
        'isLocked': isLocked,
        'powerUsageWatts': powerUsageWatts,
        'customData': customData,
      };

  factory SmartDevice.fromJson(Map<String, dynamic> json) => SmartDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        roomId: json['roomId'] as String,
        type: DeviceType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DeviceType.light,
        ),
        isOn: json['isOn'] as bool? ?? false,
        brightness: json['brightness'] as int? ?? 100,
        connection: DeviceConnection.values.firstWhere(
          (e) => e.name == json['connection'],
          orElse: () => DeviceConnection.online,
        ),
        targetTemperature:
            (json['targetTemperature'] as num?)?.toDouble() ?? 24.0,
        currentTemperature:
            (json['currentTemperature'] as num?)?.toDouble() ?? 25.0,
        currentHumidity: (json['currentHumidity'] as num?)?.toDouble() ?? 55.0,
        position: json['position'] as int? ?? 0,
        isLocked: json['isLocked'] as bool? ?? true,
        powerUsageWatts: (json['powerUsageWatts'] as num?)?.toDouble() ?? 0.0,
        customData: json['customData'] is Map
            ? Map<String, dynamic>.from(json['customData'] as Map)
            : const {},
      );
}
