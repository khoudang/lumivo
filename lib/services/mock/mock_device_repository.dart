import 'dart:async';
import '../../core/models/device_command.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';
import '../simulation/command_pipeline.dart';
import '../storage/home_persistence_manager.dart';

class MockDeviceRepository implements DeviceRepository {
  MockDeviceRepository({
    this.responseDelay = const Duration(milliseconds: 380),
    List<SmartDevice>? initialDevices,
    this.persistenceManager,
    CommandPipeline? commandPipeline,
    this.offlineErrorMessage = 'Device offline',
  }) : commandPipeline = commandPipeline ??
            CommandPipeline(
              simulatedLatency:
                  responseDelay == Duration.zero ? Duration.zero : null,
              minLatencyMs: responseDelay == Duration.zero ? 0 : 20,
              maxLatencyMs: responseDelay == Duration.zero
                  ? 0
                  : (responseDelay.inMilliseconds > 60
                      ? responseDelay.inMilliseconds
                      : 60),
            ) {
    if (initialDevices != null) {
      _devices.clear();
      _devices.addAll(initialDevices);
    } else if (persistenceManager != null &&
        persistenceManager!.cachedState != null &&
        persistenceManager!.cachedState!.devices.isNotEmpty) {
      _devices.clear();
      _devices.addAll(persistenceManager!.cachedState!.devices);
    }
    _rebuildIndex();
  }

  final Duration responseDelay;
  final HomePersistenceManager? persistenceManager;
  final CommandPipeline commandPipeline;
  final String offlineErrorMessage;
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

  List<SmartDevice> _devices = List.of(_defaultDevices);
  final Map<String, int> _deviceIndex = {};

  void _rebuildIndex() {
    _deviceIndex.clear();
    for (int i = 0; i < _devices.length; i++) {
      _deviceIndex[_devices[i].id] = i;
    }
  }

  int _findDeviceIndex(String id) {
    final cached = _deviceIndex[id];
    if (cached != null &&
        cached < _devices.length &&
        _devices[cached].id == id) {
      return cached;
    }
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      _deviceIndex[id] = idx;
    }
    return idx;
  }

  /// O(1) indexed device query by id.
  SmartDevice? getDeviceById(String id) {
    final idx = _findDeviceIndex(id);
    return idx >= 0 ? _devices[idx] : null;
  }

  /// Direct query for devices in a specific room.
  List<SmartDevice> getDevicesForRoom(String roomId) {
    return _devices.where((d) => d.roomId == roomId).toList();
  }

  List<SmartDevice> get devices => List.unmodifiable(_devices);

  void replaceAllDevices(List<SmartDevice> devices) {
    _devices = List.of(devices);
    _rebuildIndex();
    _notifyListeners();
    _persist();
  }

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

  List<SmartDevice> getDevicesForHome(String homeId) {
    return _devices.where((d) => d.homeId == homeId).toList();
  }

  Future<void> reorderFavorites(List<String> orderedDeviceIds) async {
    for (int i = 0; i < orderedDeviceIds.length; i++) {
      final id = orderedDeviceIds[i];
      final idx = _findDeviceIndex(id);
      if (idx >= 0) {
        _devices[idx] = _devices[idx].copyWith(
          isFavorite: true,
          favoriteOrder: i,
        );
      }
    }
    _rebuildIndex();
    _notifyListeners();
    await _persist();
  }

  Future<void> updateDeviceSettings(
    String deviceId, {
    String? name,
    String? customIcon,
    bool? isFavorite,
    String? roomId,
  }) async {
    final index = _findDeviceIndex(deviceId);
    if (index >= 0) {
      final current = _devices[index];
      _devices[index] = current.copyWith(
        name: name ?? current.name,
        customIcon: customIcon ?? current.customIcon,
        isFavorite: isFavorite ?? current.isFavorite,
        roomId: roomId ?? current.roomId,
      );
      _notifyListeners();
      await _persist();
    }
  }

  Future<void> removeDeviceWithCascade(String deviceId) async {
    if (persistenceManager != null) {
      await persistenceManager!.deleteDeviceWithCascade(deviceId);
      final reloaded = await persistenceManager!.loadHomeState();
      _devices
        ..clear()
        ..addAll(reloaded.devices);
    } else {
      final index = _findDeviceIndex(deviceId);
      if (index >= 0) {
        _devices.removeAt(index);
        final favs = _devices.where((d) => d.isFavorite).toList()
          ..sort((a, b) => a.favoriteOrder.compareTo(b.favoriteOrder));
        for (int i = 0; i < favs.length; i++) {
          final devIdx = _findDeviceIndex(favs[i].id);
          if (devIdx >= 0) {
            _devices[devIdx] = _devices[devIdx].copyWith(favoriteOrder: i);
          }
        }
      }
    }
    _rebuildIndex();
    _notifyListeners();
  }

  Future<void> removeRoomWithCascade(String roomId,
      {String? reassignToRoomId}) async {
    if (persistenceManager != null) {
      await persistenceManager!
          .deleteRoomWithCascade(roomId, reassignToRoomId: reassignToRoomId);
      final reloaded = await persistenceManager!.loadHomeState();
      _devices
        ..clear()
        ..addAll(reloaded.devices);
    } else {
      for (int i = 0; i < _devices.length; i++) {
        if (_devices[i].roomId == roomId) {
          if (reassignToRoomId != null) {
            _devices[i] = _devices[i].copyWith(roomId: reassignToRoomId);
          }
        }
      }
      if (reassignToRoomId == null) {
        _devices.removeWhere((d) => d.roomId == roomId);
      }
    }
    _rebuildIndex();
    _notifyListeners();
  }

  Future<void> deleteHomeWithCascade(String homeId) async {
    if (persistenceManager != null) {
      await persistenceManager!.deleteHomeWithCascade(homeId);
      final reloaded = await persistenceManager!.loadHomeState();
      _devices
        ..clear()
        ..addAll(reloaded.devices);
    } else {
      _devices.removeWhere((d) => d.homeId == homeId);
    }
    _rebuildIndex();
    _notifyListeners();
  }

  void addDevice(SmartDevice device) {
    final index = _findDeviceIndex(device.id);
    if (index >= 0) {
      _devices[index] = device;
    } else {
      _devices.add(device);
      _deviceIndex[device.id] = _devices.length - 1;
    }
    _notifyListeners();
    _persist();
  }

  void removeDevice(String deviceId) {
    final index = _findDeviceIndex(deviceId);
    if (index >= 0) {
      _devices.removeAt(index);
      _rebuildIndex();
      _notifyListeners();
      _persist();
    }
  }

  void deleteDevice(String deviceId) => removeDevice(deviceId);

  void updateDevice(SmartDevice device) {
    final index = _findDeviceIndex(device.id);
    if (index >= 0) {
      _devices[index] = device;
      _notifyListeners();
      _persist();
    }
  }

  void toggleDeviceConnection(String deviceId) {
    final index = _findDeviceIndex(deviceId);
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

  void forceDeviceOffline(String deviceId) {
    final index = _findDeviceIndex(deviceId);
    if (index >= 0) {
      _devices[index] =
          _devices[index].copyWith(connection: DeviceConnection.offline);
      _notifyListeners();
      _persist();
    }
  }

  void reconnectDevice(String deviceId) {
    final index = _findDeviceIndex(deviceId);
    if (index >= 0) {
      _devices[index] =
          _devices[index].copyWith(connection: DeviceConnection.online);
      _notifyListeners();
      _persist();
    }
  }

  void resetToDefaults() {
    _devices.clear();
    _devices.addAll(_defaultDevices);
    _rebuildIndex();
    _notifyListeners();
    _persist();
  }

  void resetToDemo() {
    _devices.clear();
    _devices.addAll(HomePersistenceManager.allDemoDevices);
    _rebuildIndex();
    _notifyListeners();
    _persist();
  }

  Future<void> loadFromPersistence() async {
    if (persistenceManager != null) {
      final homeState = await persistenceManager!.loadHomeState();
      if (homeState.devices.isNotEmpty) {
        _devices.clear();
        _devices.addAll(homeState.devices);
        _rebuildIndex();
        _notifyListeners();
      }
    }
  }

  Future<void> _persist() async {
    await persistenceManager?.saveDevices(List.of(_devices));
  }

  void _notifyListeners() {
    if (!_updates.isClosed) {
      _updates.add(List.unmodifiable(_devices));
    }
  }

  @override
  Future<CommandResult> sendCommand(DeviceCommand command) async {
    return commandPipeline.execute(
      command,
      onExecute: (cmd) async {
        final index = _findDeviceIndex(cmd.deviceId);
        if (index < 0) {
          return CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Device not found',
          );
        }
        final current = _devices[index];
        if (!current.isOnline) {
          return CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.failed,
            errorMessage: offlineErrorMessage,
          );
        }
        SmartDevice next;
        switch (cmd.type) {
          case DeviceCommandType.setPower:
            if (cmd.value is! bool) {
              return CommandResult(
                requestId: cmd.requestId,
                status: CommandStatus.failed,
                errorMessage: 'Expected boolean',
              );
            }
            next = current.copyWith(isOn: cmd.value as bool);
            break;

          case DeviceCommandType.setBrightness:
            if (current.type != DeviceType.light || cmd.value is! int) {
              return CommandResult(
                requestId: cmd.requestId,
                status: CommandStatus.failed,
                errorMessage: 'Unsupported brightness',
              );
            }
            final level = (cmd.value as int).clamp(0, 100);
            next = current.copyWith(brightness: level, isOn: level > 0);
            break;

          case DeviceCommandType.setTargetTemperature:
            if (cmd.value is! num) {
              return CommandResult(
                requestId: cmd.requestId,
                status: CommandStatus.failed,
                errorMessage: 'Expected number for temperature',
              );
            }
            final temp = (cmd.value as num).toDouble().clamp(16.0, 30.0);
            next = current.copyWith(targetTemperature: temp);
            break;

          case DeviceCommandType.setPosition:
            if (cmd.value is! num) {
              return CommandResult(
                requestId: cmd.requestId,
                status: CommandStatus.failed,
                errorMessage: 'Expected number for position',
              );
            }
            final pos = (cmd.value as num).toInt().clamp(0, 100);
            next = current.copyWith(position: pos);
            break;

          case DeviceCommandType.setLock:
            if (cmd.value is! bool) {
              return CommandResult(
                requestId: cmd.requestId,
                status: CommandStatus.failed,
                errorMessage: 'Expected boolean for lock',
              );
            }
            final locked = cmd.value as bool;
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
          requestId: cmd.requestId,
          status: CommandStatus.confirmed,
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    commandPipeline.dispose();
    _deviceIndex.clear();
    if (!_updates.isClosed) {
      await _updates.close();
    }
  }
}
