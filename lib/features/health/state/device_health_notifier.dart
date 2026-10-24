import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/device_health.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/repositories/device_repository.dart';

/// Aggregator and state notifier for device health telemetry, fault monitoring,
/// and reactive home health scoring.
class HealthAggregator {
  HealthAggregator({
    required this.repository,
    this.persistenceManager,
    this.currentHomeId = 'home-default',
  }) {
    _init();
  }

  final DeviceRepository repository;
  final HomePersistenceManager? persistenceManager;
  final String currentHomeId;

  final StreamController<List<DeviceHealth>> _healthController =
      StreamController<List<DeviceHealth>>.broadcast();
  final StreamController<HomeHealthSummary> _summaryController =
      StreamController<HomeHealthSummary>.broadcast();

  StreamSubscription<List<SmartDevice>>? _devicesSubscription;
  final Map<String, DeviceHealth> _healthCache = {};
  List<SmartDevice> _lastDevices = [];
  bool _disposed = false;

  Stream<List<DeviceHealth>> watchDeviceHealth() {
    // Immediately emit current state on subscription
    Future.microtask(() {
      if (!_healthController.isClosed) {
        _healthController.add(_currentHealthList());
      }
    });
    return _healthController.stream;
  }

  Stream<HomeHealthSummary> watchHomeHealthSummary() {
    Future.microtask(() {
      if (!_summaryController.isClosed) {
        _summaryController.add(_computeSummary(_currentHealthList()));
      }
    });
    return _summaryController.stream;
  }

  void _init() {
    // Seed health cache from persistence if available
    if (persistenceManager != null) {
      final saved =
          persistenceManager!.getDeviceHealthRecords(homeId: currentHomeId);
      for (final h in saved) {
        _healthCache[h.deviceId] = h;
      }
    }

    _devicesSubscription = repository.watchDevices().listen(
      (devices) {
        _lastDevices = devices;
        _recomputeAndEmit();
      },
      onError: (_) {},
    );
  }

  List<DeviceHealth> _currentHealthList() {
    final homeDevices =
        _lastDevices.where((d) => d.homeId == currentHomeId).toList();

    return homeDevices.map((device) {
      final cached = _healthCache[device.id];
      final isOnline = device.connection == DeviceConnection.online;

      DeviceHealthStatus status;
      if (!isOnline) {
        status = DeviceHealthStatus.offline;
      } else if (cached != null &&
          cached.status == DeviceHealthStatus.degraded) {
        status = DeviceHealthStatus.degraded;
      } else if (cached != null && cached.failureCount > 2) {
        status = DeviceHealthStatus.warning;
      } else {
        status = DeviceHealthStatus.healthy;
      }

      final rssi = cached?.rssi ?? (isOnline ? -65 : -95);
      final battery = cached?.batteryLevel ??
          (device.customData['battery'] as int? ??
              (device.type == DeviceType.lock ||
                      device.type == DeviceType.sensor
                  ? 88
                  : null));

      final health = DeviceHealth(
        deviceId: device.id,
        status: status,
        rssi: rssi,
        batteryLevel: battery,
        isOnline: isOnline,
        lastSeen:
            isOnline ? DateTime.now() : (cached?.lastSeen ?? DateTime.now()),
        failureCount: cached?.failureCount ?? (isOnline ? 0 : 1),
        statusMessage: isOnline
            ? (status == DeviceHealthStatus.degraded
                ? 'High latency'
                : 'Optimal')
            : 'Device offline',
        homeId: currentHomeId,
      );

      _healthCache[device.id] = health;
      return health;
    }).toList();
  }

  HomeHealthSummary _computeSummary(List<DeviceHealth> healthList) {
    final total = healthList.length;
    final online = healthList.where((h) => h.isOnline).length;
    final offline = healthList.where((h) => !h.isOnline).length;
    final degraded =
        healthList.where((h) => h.status == DeviceHealthStatus.degraded).length;

    final warnings = <String>[];
    if (offline > 0) {
      warnings.add('$offline device(s) offline');
    }
    if (degraded > 0) {
      warnings.add('$degraded device(s) degraded');
    }
    for (final h in healthList) {
      if (h.failureCount > 2) {
        warnings.add('Device ${h.deviceId} repeated command failures');
      }
    }

    int score = 100;
    if (total > 0) {
      final calculated = ((online - (degraded * 0.5)) / total * 100).round();
      score = calculated.clamp(0, 100);
    }

    return HomeHealthSummary(
      homeId: currentHomeId,
      totalDevices: total,
      onlineDevices: online,
      offlineDevices: offline,
      degradedDevices: degraded,
      healthScore: score,
      warnings: warnings,
    );
  }

  void _recomputeAndEmit() {
    if (_disposed) return;
    final list = _currentHealthList();
    if (!_healthController.isClosed) {
      _healthController.add(list);
    }
    if (!_summaryController.isClosed) {
      _summaryController.add(_computeSummary(list));
    }
    persistenceManager?.saveDeviceHealthRecords(list, homeId: currentHomeId);
  }

  void updateDeviceHealth(DeviceHealth health) {
    _healthCache[health.deviceId] = health;
    _recomputeAndEmit();
  }

  void recordFailure(String deviceId, [String? errorMessage]) {
    final existing = _healthCache[deviceId];
    final count = (existing?.failureCount ?? 0) + 1;
    final updated = DeviceHealth(
      deviceId: deviceId,
      status: count > 3
          ? DeviceHealthStatus.offline
          : (count > 1
              ? DeviceHealthStatus.degraded
              : DeviceHealthStatus.warning),
      rssi: existing?.rssi ?? -75,
      batteryLevel: existing?.batteryLevel,
      isOnline: count <= 3,
      lastSeen: DateTime.now(),
      failureCount: count,
      statusMessage: errorMessage ?? 'Command execution failed ($count)',
      homeId: currentHomeId,
    );
    updateDeviceHealth(updated);
  }

  void recordSuccess(String deviceId) {
    final existing = _healthCache[deviceId];
    final updated = DeviceHealth(
      deviceId: deviceId,
      status: DeviceHealthStatus.healthy,
      rssi: existing?.rssi ?? -60,
      batteryLevel: existing?.batteryLevel,
      isOnline: true,
      lastSeen: DateTime.now(),
      failureCount: 0,
      statusMessage: 'Optimal',
      homeId: currentHomeId,
    );
    updateDeviceHealth(updated);
  }

  DeviceHealth? getHealth(String deviceId) => _healthCache[deviceId];

  void dispose() {
    _disposed = true;
    _devicesSubscription?.cancel();
    _healthController.close();
    _summaryController.close();
  }
}

/// Provider for the [HealthAggregator] instance scoped to the current active home.
final healthAggregatorProvider = Provider<HealthAggregator>((ref) {
  final repo = ref.watch(deviceRepositoryProvider);
  final persistence = ref.watch(homePersistenceProvider);
  final currentHome = ref.watch(currentHomeProvider);

  final aggregator = HealthAggregator(
    repository: repo,
    persistenceManager: persistence,
    currentHomeId: currentHome.id,
  );

  ref.onDispose(() {
    aggregator.dispose();
  });

  return aggregator;
});

/// Reactive stream of device health items for the active home.
final deviceHealthProvider = StreamProvider<List<DeviceHealth>>((ref) {
  final aggregator = ref.watch(healthAggregatorProvider);
  return aggregator.watchDeviceHealth();
});

/// Reactive stream of the high-level home health summary score and active warnings.
final homeHealthSummaryProvider = StreamProvider<HomeHealthSummary>((ref) {
  final aggregator = ref.watch(healthAggregatorProvider);
  return aggregator.watchHomeHealthSummary();
});
