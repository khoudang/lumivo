import '../../services/security/secret_sanitizer.dart';

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
    this.homeId = 'home-default',
    this.isFavorite = false,
    this.favoriteOrder = 0,
    this.customIcon,
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
  final String homeId;
  final bool isFavorite;
  final int favoriteOrder;
  final String? customIcon;

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
    String? homeId,
    bool? isFavorite,
    int? favoriteOrder,
    String? customIcon,
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
        homeId: homeId ?? this.homeId,
        isFavorite: isFavorite ?? this.isFavorite,
        favoriteOrder: favoriteOrder ?? this.favoriteOrder,
        customIcon: customIcon ?? this.customIcon,
      );

  static Map<String, dynamic> sanitizeCustomData(Map<String, dynamic> data) {
    return SecretSanitizer.sanitizeMap(data);
  }

  static double _safeDouble(dynamic value,
      {double defaultValue = 0.0, bool clampNonNegative = false}) {
    if (value is num) {
      if (value.isNaN || value.isInfinite) return defaultValue;
      final d = value.toDouble();
      if (clampNonNegative && d < 0.0) return 0.0;
      return d;
    }
    return defaultValue;
  }

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
        'customData': sanitizeCustomData(customData),
        'homeId': homeId,
        'isFavorite': isFavorite,
        'favoriteOrder': favoriteOrder,
        'customIcon': customIcon,
      };

  factory SmartDevice.fromJson(Map<String, dynamic> json) => SmartDevice(
        id: json['id'] as String,
        name: ((json['name'] as String? ?? 'Device').length > 128
            ? (json['name'] as String).substring(0, 128)
            : (json['name'] as String? ?? 'Device')),
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
            _safeDouble(json['targetTemperature'], defaultValue: 24.0),
        currentTemperature:
            _safeDouble(json['currentTemperature'], defaultValue: 25.0),
        currentHumidity:
            _safeDouble(json['currentHumidity'], defaultValue: 55.0),
        position: json['position'] as int? ?? 0,
        isLocked: json['isLocked'] as bool? ?? true,
        powerUsageWatts: _safeDouble(json['powerUsageWatts'],
            defaultValue: 0.0, clampNonNegative: true),
        customData: json['customData'] is Map
            ? sanitizeCustomData(
                Map<String, dynamic>.from(json['customData'] as Map))
            : const {},
        homeId: json['homeId'] as String? ?? 'home-default',
        isFavorite: json['isFavorite'] as bool? ?? false,
        favoriteOrder: json['favoriteOrder'] as int? ?? 0,
        customIcon: json['customIcon'] as String?,
      );
}
