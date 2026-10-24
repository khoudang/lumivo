import 'dart:async';

import '../../core/models/device_health.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';
import 'command_pipeline.dart';
import 'simulation_engine.dart';

/// Health aggregator evaluating smart device telemetries across the home:
/// - Computes onlineDevices count
/// - Computes offlineDevices count
/// - Computes degradedDevices count (RSSI < -85 dBm or battery < 15%)
/// - Computes overall healthScore (0 to 100)
/// - Aggregates active warning messages
/// - Exposes `Stream<HomeHealthSummary>` and `Stream<List<DeviceHealth>>`
class HealthAggregator {
  HealthAggregator({
    DeviceRepository? repository,
    SimulationEngine? simulationEngine,
    List<SmartDevice>? initialDevices,
    this.homeId = 'home-default',
  }) {
    if (initialDevices != null) {
      evaluate(initialDevices);
    }
    if (repository != null) {
      _repoSub = repository.watchDevices().listen((devices) {
        evaluate(devices);
      });
    }
    if (simulationEngine != null) {
      _simSub = simulationEngine.snapshotStream.listen((snapshot) {
        evaluate(snapshot.devices);
      });
    }
  }

  final String homeId;
  StreamSubscription<List<SmartDevice>>? _repoSub;
  StreamSubscription<SimulationSnapshot>? _simSub;

  final StreamController<HomeHealthSummary> _summaryController =
      StreamController<HomeHealthSummary>.broadcast(sync: true);
  final StreamController<List<DeviceHealth>> _deviceHealthController =
      StreamController<List<DeviceHealth>>.broadcast(sync: true);

  HomeHealthSummary? _currentSummary;
  List<DeviceHealth> _currentDeviceHealth = [];

  HomeHealthSummary? get currentSummary => _currentSummary;
  List<DeviceHealth> get currentDeviceHealth =>
      List.unmodifiable(_currentDeviceHealth);

  Stream<HomeHealthSummary> get summaryStream => _summaryController.stream;
  Stream<List<DeviceHealth>> get deviceHealthStream =>
      _deviceHealthController.stream;

  /// Evaluates active devices and computes health metrics.
  HomeHealthSummary evaluate(Iterable<SmartDevice> devices) {
    final devList = devices.toList();
    final healthList = <DeviceHealth>[];
    final warnings = <String>[];

    int onlineCount = 0;
    int offlineCount = 0;
    int degradedCount = 0;

    for (final dev in devList) {
      final isOnline = dev.isOnline;
      final rssi = (dev.customData['rssi'] as int?) ?? (isOnline ? -60 : -95);
      final battery = (dev.customData['batteryLevel'] as int?) ??
          (dev.customData['battery'] as int?);
      final failureCount = (dev.customData['failureCount'] as int?) ?? 0;

      DeviceHealthStatus status;
      String statusMessage;

      if (!isOnline) {
        offlineCount++;
        status = DeviceHealthStatus.offline;
        statusMessage = 'Device is offline';
        warnings.add('Device "${dev.name}" is offline.');
      } else {
        onlineCount++;
        // Degraded: RSSI < -85 dBm or battery < 15%
        final bool weakSignal = rssi < -85;
        final bool lowBattery = battery != null && battery < 15;

        if (weakSignal || lowBattery) {
          degradedCount++;
          status = DeviceHealthStatus.degraded;
          if (weakSignal && lowBattery) {
            statusMessage =
                'Weak signal ($rssi dBm) and low battery ($battery%)';
            warnings.add(
                'Device "${dev.name}" has weak Wi-Fi signal ($rssi dBm) and low battery ($battery%).');
          } else if (weakSignal) {
            statusMessage = 'Weak signal ($rssi dBm)';
            warnings
                .add('Device "${dev.name}" has weak Wi-Fi signal ($rssi dBm).');
          } else {
            statusMessage = 'Low battery ($battery%)';
            warnings.add('Device "${dev.name}" battery is low ($battery%).');
          }
        } else if (failureCount > 0) {
          status = DeviceHealthStatus.warning;
          statusMessage = 'Minor communication failures ($failureCount)';
        } else {
          status = DeviceHealthStatus.healthy;
          statusMessage = 'Healthy';
        }
      }

      healthList.add(DeviceHealth(
        deviceId: dev.id,
        status: status,
        rssi: rssi,
        batteryLevel: battery,
        isOnline: isOnline,
        lastSeen: DateTime.now(),
        failureCount: failureCount,
        statusMessage: statusMessage,
        homeId: dev.homeId,
      ));
    }

    // Health Score calculation (0 - 100)
    int score = 100;
    if (devList.isNotEmpty) {
      final healthyCount = devList.length - offlineCount - degradedCount;
      score = ((healthyCount * 100 + degradedCount * 50) / devList.length)
          .round()
          .clamp(0, 100);
    }

    final summary = HomeHealthSummary(
      homeId: homeId,
      totalDevices: devList.length,
      onlineDevices: onlineCount,
      offlineDevices: offlineCount,
      degradedDevices: degradedCount,
      healthScore: score,
      warnings: List.unmodifiable(warnings),
    );

    _currentSummary = summary;
    _currentDeviceHealth = healthList;

    if (!_summaryController.isClosed) {
      _summaryController.add(summary);
    }
    if (!_deviceHealthController.isClosed) {
      _deviceHealthController.add(List.unmodifiable(healthList));
    }

    return summary;
  }

  void dispose() {
    _repoSub?.cancel();
    _simSub?.cancel();
    _summaryController.close();
    _deviceHealthController.close();
  }
}
