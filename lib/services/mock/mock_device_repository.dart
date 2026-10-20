import 'dart:async';
import '../../core/models/device_command.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';
import '../storage/home_persistence_manager.dart';

class MockDeviceRepository implements DeviceRepository {
  MockDeviceRepository({
    this.responseDelay = const Duration(milliseconds: 380),
    List<SmartDevice>? initialDevices,
    this.persistenceManager,
  }) {
    if (initialDevices != null) {
      _devices.clear();
      _devices.addAll(initialDevices);
    } else if (persistenceManager != null &&
        persistenceManager!.cachedState != null &&
        persistenceManager!.cachedState!.devices.isNotEmpty) {
      _devices.clear();
      _devices.addAll(persistenceManager!.cachedState!.devices);
    }
  }

  final Duration responseDelay;
  final HomePersistenceManager? persistenceManager;
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
    _persist();
  }

  void updateDevice(SmartDevice device) {
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      _devices[index] = device;
      _notifyListeners();
      _persist();
    }
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
      _persist();
    }
  }

  void resetToDefaults() {
    _devices.clear();
    _devices.addAll(_defaultDevices);
    _notifyListeners();
    _persist();
  }

  void resetToDemo() {
    _devices.clear();
    _devices.addAll(HomePersistenceManager.defaultDemoDevices);
    _notifyListeners();
    _persist();
  }

  Future<void> loadFromPersistence() async {
    if (persistenceManager != null) {
      final homeState = await persistenceManager!.loadHomeState();
      if (homeState.devices.isNotEmpty) {
        _devices.clear();
        _devices.addAll(homeState.devices);
        _notifyListeners();
      }
    }
  }

  void _persist() {
    persistenceManager?.saveDevices(List.of(_devices));
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

      case DeviceCommandType.setTargetTemperature:
        if (command.value is! num) {
          return CommandResult(
            requestId: command.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Expected number for temperature',
          );
        }
        final temp = (command.value as num).toDouble().clamp(16.0, 30.0);
        next = current.copyWith(targetTemperature: temp);
        break;

      case DeviceCommandType.setPosition:
        if (command.value is! num) {
          return CommandResult(
            requestId: command.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Expected number for position',
          );
        }
        final pos = (command.value as num).toInt().clamp(0, 100);
        next = current.copyWith(position: pos);
        break;

      case DeviceCommandType.setLock:
        if (command.value is! bool) {
          return CommandResult(
            requestId: command.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Expected boolean for lock',
          );
        }
        final locked = command.value as bool;
        next = current.copyWith(isLocked: locked);
        break;

      case DeviceCommandType.toggleLock:
        next = current.copyWith(isLocked: !current.isLocked);
        break;
    }

    _devices[index] = next;
    _notifyListeners();
    _persist();

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
