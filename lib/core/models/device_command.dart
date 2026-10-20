enum DeviceCommandType {
  setPower,
  setBrightness,
  setTargetTemperature,
  setPosition,
  setLock,
  toggleLock,
}

enum CommandStatus { confirmed, failed, pending, timedOut }

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
