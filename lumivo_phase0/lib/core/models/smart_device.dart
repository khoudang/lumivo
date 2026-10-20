enum DeviceType { light, fan, security }

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
  });

  final String id;
  final String name;
  final String roomId;
  final DeviceType type;
  final bool isOn;
  final int brightness;
  final DeviceConnection connection;

  SmartDevice copyWith(
          {bool? isOn, int? brightness, DeviceConnection? connection}) =>
      SmartDevice(
        id: id,
        name: name,
        roomId: roomId,
        type: type,
        isOn: isOn ?? this.isOn,
        brightness: brightness ?? this.brightness,
        connection: connection ?? this.connection,
      );
}
