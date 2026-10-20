import 'smart_device.dart';

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.type,
    this.advertisedServiceUuid,
    this.isProvisioned = false,
  });

  final String id;
  final String name;
  final int rssi;
  final DeviceType type;
  final String? advertisedServiceUuid;
  final bool isProvisioned;

  DiscoveredDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    DeviceType? type,
    String? advertisedServiceUuid,
    bool? isProvisioned,
  }) =>
      DiscoveredDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        rssi: rssi ?? this.rssi,
        type: type ?? this.type,
        advertisedServiceUuid:
            advertisedServiceUuid ?? this.advertisedServiceUuid,
        isProvisioned: isProvisioned ?? this.isProvisioned,
      );
}
