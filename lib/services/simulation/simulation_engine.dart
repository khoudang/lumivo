import 'dart:async';
import '../../core/models/automation_rule.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';
import '../mock/mock_device_repository.dart';
import 'automation_engine.dart';
import 'device_simulators/ac_simulator.dart';
import 'device_simulators/bulb_simulator.dart';
import 'device_simulators/curtain_simulator.dart';
import 'device_simulators/device_simulator.dart';
import 'device_simulators/fan_simulator.dart';
import 'device_simulators/generic_device_simulator.dart';
import 'device_simulators/lock_simulator.dart';
import 'device_simulators/sensor_simulator.dart';
import 'device_simulators/socket_simulator.dart';
import 'virtual_clock.dart';

/// Point-in-time snapshot representing complete environmental and smart home state.
class SimulationSnapshot {
  const SimulationSnapshot({
    required this.virtualTime,
    required this.ambientTemperature,
    required this.ambientHumidity,
    required this.totalPowerWatts,
    this.devices = const [],
    this.offlineDeviceIds = const {},
  });

  final DateTime virtualTime;
  final double ambientTemperature;
  final double ambientHumidity;
  final double totalPowerWatts;
  final List<SmartDevice> devices;
  final Set<String> offlineDeviceIds;

  SimulationSnapshot copyWith({
    DateTime? virtualTime,
    double? ambientTemperature,
    double? ambientHumidity,
    double? totalPowerWatts,
    List<SmartDevice>? devices,
    Set<String>? offlineDeviceIds,
  }) =>
      SimulationSnapshot(
        virtualTime: virtualTime ?? this.virtualTime,
        ambientTemperature: ambientTemperature ?? this.ambientTemperature,
        ambientHumidity: ambientHumidity ?? this.ambientHumidity,
        totalPowerWatts: totalPowerWatts ?? this.totalPowerWatts,
        devices: devices ?? this.devices,
        offlineDeviceIds: offlineDeviceIds ?? this.offlineDeviceIds,
      );

  @override
  String toString() =>
      'SimulationSnapshot(time: $virtualTime, temp: ${ambientTemperature.toStringAsFixed(1)}°C, '
      'humidity: ${ambientHumidity.toStringAsFixed(1)}%, power: ${totalPowerWatts.toStringAsFixed(1)}W, '
      'devices: ${devices.length})';
}

/// Central engine coordinating the virtual clock, device simulators,
/// automation rules engine, and real-time total home power telemetry.
class SimulationEngine {
  SimulationEngine({
    VirtualClock? clock,
    AutomationEngine? automationEngine,
    this.repository,
    List<SmartDevice>? initialDevices,
    List<AutomationRule>? initialRules,
    bool autoStart = false,
  })  : clock = clock ?? VirtualClock(),
        automationEngine = automationEngine ??
            AutomationEngine(
              initialRules: initialRules,
              repository: repository,
            ) {
    _lastTickTime = this.clock.now;

    // Register initial devices or load from repository
    if (initialDevices != null && initialDevices.isNotEmpty) {
      registerDevices(initialDevices);
    } else if (repository is MockDeviceRepository) {
      registerDevices((repository as MockDeviceRepository).devices);
    }

    if (repository != null) {
      _repoSubscription =
          repository!.watchDevices().listen(_onRepositoryDevicesUpdated);
    }

    _snapshot = _computeSnapshot();

    _clockSubscription = this.clock.tickStream.listen((time) {
      _onClockTick(time);
    });

    if (autoStart) {
      this.clock.start();
    }
  }

  static SimulationEngine? _instance;

  /// Global singleton instance for app-wide simulation coordination.
  static SimulationEngine get instance =>
      _instance ??= SimulationEngine(autoStart: true);

  /// Resets the global singleton instance (useful for clean test teardown).
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  final VirtualClock clock;
  final AutomationEngine automationEngine;
  final DeviceRepository? repository;

  final Map<String, SmartDevice> _devices = {};
  final Map<String, DeviceSimulator> _simulators = {};
  final Set<String> _forcedOfflineDeviceIds = {};

  double? _forcedAmbientTemperature;
  double? _forcedAmbientHumidity;

  late DateTime _lastTickTime;
  late SimulationSnapshot _snapshot;
  final StreamController<SimulationSnapshot> _snapshotController =
      StreamController<SimulationSnapshot>.broadcast(sync: true);

  StreamSubscription<DateTime>? _clockSubscription;
  StreamSubscription<List<SmartDevice>>? _repoSubscription;
  bool _isDisposed = false;

  /// Current telemetry snapshot.
  SimulationSnapshot get currentSnapshot => _snapshot;

  /// Stream of emitted snapshots on every virtual tick or environmental change.
  Stream<SimulationSnapshot> get snapshotStream => _snapshotController.stream;

  /// Read-only view of current devices.
  List<SmartDevice> get devices => List.unmodifiable(_devices.values);

  /// Retrieves the active simulator for [deviceId].
  DeviceSimulator? getSimulator(String deviceId) => _simulators[deviceId];

  /// Registers a list of smart devices into the simulation engine.
  void registerDevices(Iterable<SmartDevice> devices) {
    for (final device in devices) {
      registerDevice(device);
    }
  }

  /// Registers or updates a device and creates its simulator.
  void registerDevice(SmartDevice device) {
    _devices[device.id] = device;
    final existingSim = _simulators[device.id];
    if (existingSim != null) {
      existingSim.updateDevice(device);
    } else {
      _simulators[device.id] = _createSimulator(device);
    }
  }

  /// Unregisters a device by its identifier.
  void unregisterDevice(String deviceId) {
    _devices.remove(deviceId);
    _simulators.remove(deviceId);
    _forcedOfflineDeviceIds.remove(deviceId);
  }

  DeviceSimulator _createSimulator(SmartDevice device) {
    switch (device.type) {
      case DeviceType.light:
        return BulbSimulator(device);
      case DeviceType.fan:
        return FanSimulator(device);
      case DeviceType.ac:
        return AcSimulator(device);
      case DeviceType.socket:
        return SocketSimulator(device);
      case DeviceType.curtain:
        return CurtainSimulator(device);
      case DeviceType.lock:
        return LockSimulator(device);
      case DeviceType.sensor:
        return SensorSimulator(device);
      case DeviceType.security:
        return GenericDeviceSimulator(device);
    }
  }

  void _onRepositoryDevicesUpdated(List<SmartDevice> repoDevices) {
    for (final d in repoDevices) {
      final isForcedOffline = _forcedOfflineDeviceIds.contains(d.id);
      final adjustedDevice = isForcedOffline
          ? d.copyWith(connection: DeviceConnection.offline)
          : d;
      _devices[d.id] = adjustedDevice;
      if (_simulators.containsKey(d.id)) {
        _simulators[d.id]!.updateDevice(adjustedDevice);
      } else {
        _simulators[d.id] = _createSimulator(adjustedDevice);
      }
    }
    _emitUpdatedSnapshot();
  }

  Future<void> _onClockTick(DateTime newTime) async {
    Duration elapsed = newTime.difference(_lastTickTime);
    if (elapsed < Duration.zero) {
      elapsed = Duration.zero;
    }
    _lastTickTime = newTime;

    final double ambientTemp = _forcedAmbientTemperature ??
        SensorSimulator.computeDiurnalTemperature(newTime);
    final double ambientHumidity = _forcedAmbientHumidity ??
        SensorSimulator.computeDiurnalHumidity(newTime);

    // Check for active AC in rooms to compute thermal coupling
    AcSimulator? activeAcSim;
    for (final sim in _simulators.values) {
      if (sim is AcSimulator && sim.device.isOn) {
        if (!_forcedOfflineDeviceIds.contains(sim.device.id) &&
            sim.device.connection == DeviceConnection.online) {
          activeAcSim = sim;
          break;
        }
      }
    }

    // Tick each simulator
    for (final sim in _simulators.values) {
      final isOffline = _forcedOfflineDeviceIds.contains(sim.device.id) ||
          sim.device.connection == DeviceConnection.offline;

      if (!isOffline) {
        final updated = sim.tick(
          elapsed,
          context: {
            'virtualTime': newTime,
            'ambientTemperature': ambientTemp,
            'ambientHumidity': ambientHumidity,
            'acTemperature': activeAcSim?.device.targetTemperature,
            'isAcActive': activeAcSim != null,
          },
        );
        _devices[updated.id] = updated;

        // If repository is a MockDeviceRepository, synchronize updated device
        if (repository is MockDeviceRepository) {
          (repository as MockDeviceRepository).addDevice(updated);
        }
      }
    }

    // Evaluate automation rules
    await automationEngine.evaluate(
      virtualTime: newTime,
      devices: _devices.values,
    );

    _emitUpdatedSnapshot();
  }

  SimulationSnapshot _computeSnapshot() {
    final double ambientTemp = _forcedAmbientTemperature ??
        SensorSimulator.computeDiurnalTemperature(clock.now);
    final double ambientHumidity = _forcedAmbientHumidity ??
        SensorSimulator.computeDiurnalHumidity(clock.now);

    double totalWatts = 0.0;
    for (final sim in _simulators.values) {
      final isOffline = _forcedOfflineDeviceIds.contains(sim.device.id) ||
          sim.device.connection == DeviceConnection.offline;
      if (!isOffline) {
        totalWatts += sim.powerUsageWatts;
      }
    }

    return SimulationSnapshot(
      virtualTime: clock.now,
      ambientTemperature: ambientTemp,
      ambientHumidity: ambientHumidity,
      totalPowerWatts: (totalWatts * 100).roundToDouble() / 100.0,
      devices: List.unmodifiable(_devices.values),
      offlineDeviceIds: Set.unmodifiable(_forcedOfflineDeviceIds),
    );
  }

  void _emitUpdatedSnapshot() {
    _snapshot = _computeSnapshot();
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_snapshot);
    }
  }

  // ==========================================
  // Chaos and Demo Lab Controls
  // ==========================================

  /// Forces a device online or offline (chaos injection).
  void forceDeviceOffline(String deviceId, bool offline) {
    if (offline) {
      _forcedOfflineDeviceIds.add(deviceId);
      if (_devices.containsKey(deviceId)) {
        final updated =
            _devices[deviceId]!.copyWith(connection: DeviceConnection.offline);
        _devices[deviceId] = updated;
        _simulators[deviceId]?.updateDevice(updated);
        if (repository is MockDeviceRepository) {
          (repository as MockDeviceRepository).addDevice(updated);
        }
      }
    } else {
      _forcedOfflineDeviceIds.remove(deviceId);
      if (_devices.containsKey(deviceId)) {
        final updated =
            _devices[deviceId]!.copyWith(connection: DeviceConnection.online);
        _devices[deviceId] = updated;
        _simulators[deviceId]?.updateDevice(updated);
        if (repository is MockDeviceRepository) {
          (repository as MockDeviceRepository).addDevice(updated);
        }
      }
    }
    _emitUpdatedSnapshot();
  }

  /// Sets the simulated virtual time.
  void setVirtualTime(DateTime time) {
    clock.setTime(time);
  }

  /// Sets the virtual clock speed multiplier.
  void setMultiplier(double multiplier) {
    clock.setMultiplier(multiplier);
  }

  /// Manually advances the virtual clock by [duration].
  void advanceTime(Duration duration) {
    clock.advance(duration);
  }

  /// Forces ambient temperature (overriding diurnal curve). Pass null to clear.
  void forceAmbientTemperature(double? temp) {
    _forcedAmbientTemperature = temp;
    _emitUpdatedSnapshot();
  }

  /// Forces ambient humidity (overriding diurnal curve). Pass null to clear.
  void forceAmbientHumidity(double? humidity) {
    _forcedAmbientHumidity = humidity;
    _emitUpdatedSnapshot();
  }

  /// Injects simulated sensor telemetry for [deviceId] and re-evaluates automation rules.
  void triggerSimulatedSensorUpdate(
    String deviceId,
    double temp,
    double humidity,
  ) {
    final existing = _devices[deviceId];
    if (existing != null) {
      final updated = existing.copyWith(
        currentTemperature: temp,
        currentHumidity: humidity,
      );
      _devices[deviceId] = updated;
      final sim = _simulators[deviceId];
      if (sim is SensorSimulator) {
        sim.forcedTemperature = temp;
        sim.forcedHumidity = humidity;
      }
      sim?.updateDevice(updated);

      if (repository is MockDeviceRepository) {
        (repository as MockDeviceRepository).addDevice(updated);
      }

      automationEngine.evaluate(
        virtualTime: clock.now,
        devices: _devices.values,
      );

      _emitUpdatedSnapshot();
    }
  }

  /// Cleans up resources, timers, and stream controllers.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _clockSubscription?.cancel();
    _repoSubscription?.cancel();
    clock.dispose();
    automationEngine.dispose();
    _snapshotController.close();
  }
}
