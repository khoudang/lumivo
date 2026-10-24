enum DeviceCommandType {
  setPower,
  setBrightness,
  setTargetTemperature,
  setPosition,
  setLock,
  toggleLock,
}

enum CommandStatus {
  queued,
  pending,
  confirmed,
  failed,
  timedOut,
  cancelled,
}

class DeviceCommand {
  const DeviceCommand({
    required this.requestId,
    required this.deviceId,
    required this.type,
    required this.value,
  });

  final String requestId;
  final String deviceId;
  final DeviceCommandType type;
  final Object value;
}

class CommandResult {
  const CommandResult({
    required this.requestId,
    required this.status,
    this.errorMessage,
  });

  final String requestId;
  final CommandStatus status;
  final String? errorMessage;
}

/// Persistent record of an executed command through the authoritative pipeline.
class CommandRecord {
  const CommandRecord({
    required this.requestId,
    required this.deviceId,
    required this.type,
    required this.value,
    required this.status,
    required this.timestamp,
    this.executionDuration = Duration.zero,
    this.errorMessage,
    this.retryCount = 0,
    this.homeId = 'home-default',
  });

  final String requestId;
  final String deviceId;
  final DeviceCommandType type;
  final Object value;
  final CommandStatus status;
  final DateTime timestamp;
  final Duration executionDuration;
  final String? errorMessage;
  final int retryCount;
  final String homeId;

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'deviceId': deviceId,
        'type': type.name,
        'value': value,
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'executionDurationMs': executionDuration.inMilliseconds,
        'errorMessage': errorMessage,
        'retryCount': retryCount,
        'homeId': homeId,
      };

  factory CommandRecord.fromJson(Map<String, dynamic> json) => CommandRecord(
        requestId: json['requestId'] as String? ?? '',
        deviceId: json['deviceId'] as String? ?? '',
        type: DeviceCommandType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DeviceCommandType.setPower,
        ),
        value: json['value'] as Object? ?? false,
        status: CommandStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => CommandStatus.confirmed,
        ),
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        executionDuration: Duration(
          milliseconds: json['executionDurationMs'] as int? ?? 0,
        ),
        errorMessage: json['errorMessage'] as String?,
        retryCount: json['retryCount'] as int? ?? 0,
        homeId: json['homeId'] as String? ?? 'home-default',
      );
}
