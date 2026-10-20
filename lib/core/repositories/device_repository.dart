import '../models/device_command.dart';
import '../models/smart_device.dart';

abstract interface class DeviceRepository {
  Stream<List<SmartDevice>> watchDevices();
  Future<CommandResult> sendCommand(DeviceCommand command);
  Future<void> dispose();
}
