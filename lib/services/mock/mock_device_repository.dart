import 'dart:async';
import '../../core/models/device_command.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';

class MockDeviceRepository implements DeviceRepository {
  MockDeviceRepository({
    this.responseDelay = const Duration(milliseconds: 380),
    List<SmartDevice>? initialDevices,
  }) {
    if (initialDevices != null) {
      _devices.clear();
      _devices.addAll(initialDevices);
    }
  }

  final Duration responseDelay;
  final StreamController<List<SmartDevice>> _updates =
      StreamController<List<SmartDevice>>.broadcast();

  static const List<SmartDevice> _defaultDevices = [
    SmartDevice(
      id: 'light-1',
      name: 'Smart Light',
      roomId: 'Living Room',
      type: DeviceType.light,
      isOn: true,
      brightness: 72,
    ),
    SmartDevice(
      id: 'fan-1',
      name: 'Smart Fan',
      roomId: 'Living Room',
      type: DeviceType.fan,
      isOn: false,
    ),
    SmartDevice(
      id: 'security-1',
      name: 'Home Security',
      roomId: 'Living Room',
      type: DeviceType.security,
      isOn: true,
    ),
    SmartDevice(
      id: 'light-2',
      name: 'Bedside Light',
      roomId: 'Bedroom',
      type: DeviceType.light,
      isOn: false,
      brightness: 45,
    ),
    SmartDevice(
      id: 'fan-2',
      name: 'Bedroom Fan',
      roomId: 'Bedroom',
      type: DeviceType.fan,
      isOn: true,
    ),
    SmartDevice(
      id: 'light-3',
      name: 'Kitchen Light',
      roomId: 'Kitchen',
      type: DeviceType.light,
      isOn: false,
    ),
  ];

  final List<SmartDevice> _devices = List.of(_defaultDevices);

  List<SmartDevice> get devices => List.unmodifiable(_devices);

  @override
  Stream<List<SmartDevice>> watchDevices() {
    late final StreamController<List<SmartDevice>> controller;
    StreamSubscription<List<SmartDevice>>? subscription;

    controller = StreamController<List<SmartDevice>>(
      onListen: () {
        controller.add(List.unmodifiable(_devices));
        subscription = _updates.stream.listen(
          (data) {
            if (!controller.isClosed) {
              controller.add(data);
            }
          },
          onError: (Object err, StackTrace st) {
            if (!controller.isClosed) {
              controller.addError(err, st);
            }
          },
          onDone: () {
            if (!controller.isClosed) {
              controller.close();
            }
          },
        );
      },
      onCancel: () {
        subscription?.cancel();
      },
    );

    return controller.stream.asBroadcastStream();
  }

  void addDevice(SmartDevice device) {
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      _devices[index] = device;
    } else {
      _devices.add(device);
    }
    _notifyListeners();
  }

  void toggleDeviceConnection(String deviceId) {
    final index = _devices.indexWhere((device) => device.id == deviceId);
    if (index >= 0) {
      final current = _devices[index];
      final nextStatus = current.connection == DeviceConnection.online
          ? DeviceConnection.offline
          : DeviceConnection.online;
      _devices[index] = current.copyWith(connection: nextStatus);
      _notifyListeners();
    }
  }

  void resetToDefaults() {
    _devices.clear();
    _devices.addAll(_defaultDevices);
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_updates.isClosed) {
      _updates.add(List.unmodifiable(_devices));
    }
  }

  @override
  Future<CommandResult> sendCommand(DeviceCommand command) async {
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
    final index =
        _devices.indexWhere((device) => device.id == command.deviceId);
    if (index < 0) {
      return CommandResult(
        requestId: command.requestId,
        status: CommandStatus.failed,
        errorMessage: 'Device not found',
      );
    }
    final current = _devices[index];
    if (current.connection == DeviceConnection.offline) {
      return CommandResult(
        requestId: command.requestId,
        status: CommandStatus.failed,
        errorMessage: 'Device offline',
      );
    }
    SmartDevice next;
    switch (command.type) {
      case DeviceCommandType.setPower:
        if (command.value is! bool) {
          return CommandResult(
            requestId: command.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Expected boolean',
          );
        }
        next = current.copyWith(isOn: command.value as bool);
        break;
      case DeviceCommandType.setBrightness:
        if (current.type != DeviceType.light || command.value is! int) {
          return CommandResult(
            requestId: command.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Unsupported brightness',
          );
        }
        final level = (command.value as int).clamp(0, 100);
        next = current.copyWith(brightness: level, isOn: level > 0);
        break;
    }
    _devices[index] = next;
    _notifyListeners();
    return CommandResult(
      requestId: command.requestId,
      status: CommandStatus.confirmed,
    );
  }

  @override
  Future<void> dispose() async {
    if (!_updates.isClosed) {
      await _updates.close();
    }
  }
}
