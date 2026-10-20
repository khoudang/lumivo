import 'dart:async';
import '../../core/models/device_command.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';

class MockDeviceRepository implements DeviceRepository {
  final _updates = StreamController<List<SmartDevice>>.broadcast();
  final List<SmartDevice> _devices = [
    const SmartDevice(id: 'light-1', name: 'Smart Light', roomId: 'Living Room', type: DeviceType.light, isOn: true, brightness: 72),
    const SmartDevice(id: 'fan-1', name: 'Smart Fan', roomId: 'Living Room', type: DeviceType.fan, isOn: false),
    const SmartDevice(id: 'security-1', name: 'Home Security', roomId: 'Living Room', type: DeviceType.security, isOn: true),
    const SmartDevice(id: 'light-2', name: 'Bedside Light', roomId: 'Bedroom', type: DeviceType.light, isOn: false, brightness: 45),
    const SmartDevice(id: 'fan-2', name: 'Bedroom Fan', roomId: 'Bedroom', type: DeviceType.fan, isOn: true),
    const SmartDevice(id: 'light-3', name: 'Kitchen Light', roomId: 'Kitchen', type: DeviceType.light, isOn: false),
  ];

  @override
  Stream<List<SmartDevice>> watchDevices() async* {
    yield List.unmodifiable(_devices);
    yield* _updates.stream;
  }

  @override
  Future<CommandResult> sendCommand(DeviceCommand command) async {
    await Future<void>.delayed(const Duration(milliseconds: 380));
    final index = _devices.indexWhere((device) => device.id == command.deviceId);
    if (index < 0) {
      return CommandResult(requestId: command.requestId, status: CommandStatus.failed, errorMessage: 'Device not found');
    }
    final current = _devices[index];
    if (current.connection == DeviceConnection.offline) {
      return CommandResult(requestId: command.requestId, status: CommandStatus.failed, errorMessage: 'Device offline');
    }
    SmartDevice next;
    switch (command.type) {
      case DeviceCommandType.setPower:
        if (command.value is! bool) {
          return CommandResult(requestId: command.requestId, status: CommandStatus.failed, errorMessage: 'Expected boolean');
        }
        next = current.copyWith(isOn: command.value as bool);
        break;
      case DeviceCommandType.setBrightness:
        if (current.type != DeviceType.light || command.value is! int) {
          return CommandResult(requestId: command.requestId, status: CommandStatus.failed, errorMessage: 'Unsupported brightness');
        }
        final level = (command.value as int).clamp(0, 100);
        next = current.copyWith(brightness: level, isOn: level > 0);
        break;
    }
    _devices[index] = next;
    if (!_updates.isClosed) _updates.add(List.unmodifiable(_devices));
    return CommandResult(requestId: command.requestId, status: CommandStatus.confirmed);
  }

  @override
  Future<void> dispose() => _updates.close();
}
