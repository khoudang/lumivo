import 'dart:async';
import '../../core/models/activity_event.dart';
import '../../core/models/automation_rule.dart';
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

  List<SmartDevice> getDevicesForHome(String homeId) {
    return _devices.where((d) => d.homeId == homeId).toList();
  }

  Future<void> reorderFavorites(List<String> orderedDeviceIds) async {
    for (int i = 0; i < orderedDeviceIds.length; i++) {
      final id = orderedDeviceIds[i];
      final idx = _devices.indexWhere((d) => d.id == id);
      if (idx >= 0) {
        _devices[idx] = _devices[idx].copyWith(
          isFavorite: true,
          favoriteOrder: i,
        );
      }
    }
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
    final index = _devices.indexWhere((device) => device.id == deviceId);
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
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index < 0) return;
    final removedDevice = _devices.removeAt(index);

    // Prune favorite orders
    final favs = _devices.where((d) => d.isFavorite).toList()
      ..sort((a, b) => a.favoriteOrder.compareTo(b.favoriteOrder));
    for (int i = 0; i < favs.length; i++) {
      final devIdx = _devices.indexWhere((d) => d.id == favs[i].id);
      if (devIdx >= 0) {
        _devices[devIdx] = _devices[devIdx].copyWith(favoriteOrder: i);
      }
    }

    if (persistenceManager != null) {
      await persistenceManager!.saveDevices(List.of(_devices));
      final currentHomeState = await persistenceManager!.loadHomeState();

      // Prune actions from Scenes
      final updatedScenes = currentHomeState.scenes.map((scene) {
        final prunedActions = scene.actions
            .where((action) => action.deviceId != deviceId)
            .toList();
        return scene.copyWith(actions: prunedActions);
      }).toList();
      await persistenceManager!.saveScenes(updatedScenes);

      // Prune or disable AutomationRules
      final updatedRules = currentHomeState.automations.map((rule) {
        final isSensorRef = rule.sensorDeviceId == deviceId;
        final prunedActions = rule.actions
            .where((action) => action.deviceId != deviceId)
            .toList();
        final shouldDisable = isSensorRef || prunedActions.isEmpty;
        if (isSensorRef) {
          return AutomationRule(
            id: rule.id,
            name: rule.name,
            isEnabled: false,
            triggerType: rule.triggerType,
            timeOfDay: rule.timeOfDay,
            daysOfWeek: rule.daysOfWeek,
            sensorDeviceId: null,
            sensorProperty: rule.sensorProperty,
            operator: rule.operator,
            thresholdValue: rule.thresholdValue,
            actions: prunedActions,
            lastExecutedAt: rule.lastExecutedAt,
            homeId: rule.homeId,
          );
        }
        return rule.copyWith(
          actions: prunedActions,
          isEnabled: shouldDisable ? false : rule.isEnabled,
        );
      }).toList();
      await persistenceManager!.saveAutomations(updatedRules);

      // Record ActivityEvent
      final cascadeEvent = ActivityEvent(
        id: 'evt-cascade-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Cascade Deletion: ${removedDevice.name}',
        description:
            'Device "$deviceId" removed. Pruned from scenes and automations.',
        timestamp: DateTime.now(),
        deviceId: deviceId,
        severity: ActivitySeverity.warning,
        source: 'system',
      );
      final currentEvents = currentHomeState.activityEvents;
      await persistenceManager!
          .saveActivityEvents([cascadeEvent, ...currentEvents]);
    }

    _notifyListeners();
  }

  Future<void> deleteHomeWithCascade(String homeId) async {
    _devices.removeWhere((d) => d.homeId == homeId);

    final favs = _devices.where((d) => d.isFavorite).toList()
      ..sort((a, b) => a.favoriteOrder.compareTo(b.favoriteOrder));
    for (int i = 0; i < favs.length; i++) {
      final devIdx = _devices.indexWhere((d) => d.id == favs[i].id);
      if (devIdx >= 0) {
        _devices[devIdx] = _devices[devIdx].copyWith(favoriteOrder: i);
      }
    }

    if (persistenceManager != null) {
      await persistenceManager!.saveDevices(List.of(_devices));
      final currentHomeState = await persistenceManager!.loadHomeState();

      final updatedRooms =
          currentHomeState.rooms.where((r) => r.homeId != homeId).toList();
      final updatedScenes =
          currentHomeState.scenes.where((s) => s.homeId != homeId).toList();
      final updatedRules = currentHomeState.automations
          .where((a) => a.homeId != homeId)
          .toList();
      final updatedHomes =
          currentHomeState.homes.where((h) => h.id != homeId).toList();

      await persistenceManager!.saveRooms(updatedRooms);
      await persistenceManager!.saveScenes(updatedScenes);
      await persistenceManager!.saveAutomations(updatedRules);
      await persistenceManager!.saveHomes(updatedHomes);

      final cascadeEvent = ActivityEvent(
        id: 'evt-home-cascade-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Home Deleted: $homeId',
        description:
            'Home "$homeId" and all associated devices, rooms, scenes, and automations were deleted.',
        timestamp: DateTime.now(),
        severity: ActivitySeverity.warning,
        source: 'system',
      );
      await persistenceManager!.saveActivityEvents([
        cascadeEvent,
        ...currentHomeState.activityEvents,
      ]);
    }

    _notifyListeners();
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

  void removeDevice(String deviceId) {
    _devices.removeWhere((d) => d.id == deviceId);
    _notifyListeners();
    _persist();
  }

  void deleteDevice(String deviceId) => removeDevice(deviceId);

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

  void forceDeviceOffline(String deviceId) {
    final index = _devices.indexWhere((device) => device.id == deviceId);
    if (index >= 0) {
      _devices[index] =
          _devices[index].copyWith(connection: DeviceConnection.offline);
      _notifyListeners();
      _persist();
    }
  }

  void reconnectDevice(String deviceId) {
    final index = _devices.indexWhere((device) => device.id == deviceId);
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
    _notifyListeners();
    _persist();
  }

  void resetToDemo() {
    _devices.clear();
    _devices.addAll(HomePersistenceManager.allDemoDevices);
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
        final index =
            _devices.indexWhere((device) => device.id == cmd.deviceId);
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
    if (!_updates.isClosed) {
      await _updates.close();
    }
  }
}
