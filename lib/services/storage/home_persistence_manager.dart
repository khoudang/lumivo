import 'dart:convert';
import '../security/secret_sanitizer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/activity_event.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/dashboard_config.dart';
import '../../core/models/device_command.dart';
import '../../core/models/device_health.dart';
import '../../core/models/energy_sample.dart';
import '../../core/models/home.dart';
import '../../core/models/in_app_notification.dart';
import '../../core/models/room.dart';
import '../../core/models/smart_device.dart';
import '../../core/models/user_profile.dart';
import 'storage_adapter.dart';
import 'storage_adapter_factory.dart';

class HomeState {
  const HomeState({
    this.schemaVersion = HomePersistenceManager.schemaVersion,
    this.homes = const [],
    this.currentHomeId = 'home-default',
    this.userProfile = HomePersistenceManager.defaultUserProfile,
    this.energySamples = const [],
    this.rooms = const [],
    this.devices = const [],
    this.automations = const [],
    this.scenes = const [],
    this.activityEvents = const [],
    this.notifications = const [],
    this.commandRecords = const [],
    this.automationRecords = const [],
    this.deviceHealthRecords = const [],
    this.simulatedModifications = const {},
    this.dashboardConfigs = const {},
  });

  final int schemaVersion;
  final List<Home> homes;
  final String currentHomeId;
  final UserProfile userProfile;
  final List<EnergySample> energySamples;
  final List<Room> rooms;
  final List<SmartDevice> devices;
  final List<AutomationRule> automations;
  final List<Scene> scenes;
  final List<ActivityEvent> activityEvents;
  final List<InAppNotification> notifications;
  final List<CommandRecord> commandRecords;
  final List<AutomationExecutionRecord> automationRecords;
  final List<DeviceHealth> deviceHealthRecords;
  final Map<String, dynamic> simulatedModifications;
  final Map<String, DashboardConfig> dashboardConfigs;

  HomeState copyWith({
    int? schemaVersion,
    List<Home>? homes,
    String? currentHomeId,
    UserProfile? userProfile,
    List<EnergySample>? energySamples,
    List<Room>? rooms,
    List<SmartDevice>? devices,
    List<AutomationRule>? automations,
    List<Scene>? scenes,
    List<ActivityEvent>? activityEvents,
    List<InAppNotification>? notifications,
    List<CommandRecord>? commandRecords,
    List<AutomationExecutionRecord>? automationRecords,
    List<DeviceHealth>? deviceHealthRecords,
    Map<String, dynamic>? simulatedModifications,
    Map<String, DashboardConfig>? dashboardConfigs,
  }) {
    return HomeState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      homes: homes ?? this.homes,
      currentHomeId: currentHomeId ?? this.currentHomeId,
      userProfile: userProfile ?? this.userProfile,
      energySamples: energySamples ?? this.energySamples,
      rooms: rooms ?? this.rooms,
      devices: devices ?? this.devices,
      automations: automations ?? this.automations,
      scenes: scenes ?? this.scenes,
      activityEvents: activityEvents ?? this.activityEvents,
      notifications: notifications ?? this.notifications,
      commandRecords: commandRecords ?? this.commandRecords,
      automationRecords: automationRecords ?? this.automationRecords,
      deviceHealthRecords: deviceHealthRecords ?? this.deviceHealthRecords,
      simulatedModifications:
          simulatedModifications ?? this.simulatedModifications,
      dashboardConfigs: dashboardConfigs ?? this.dashboardConfigs,
    );
  }

  static Map<String, dynamic> _sanitizeCustomData(Map<String, dynamic> data) {
    return SecretSanitizer.sanitizeMap(data);
  }

  static List<T> _safeListRecovery<T>(
    dynamic rawList,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (rawList is! List) return const [];
    final validItems = <T>[];
    for (final item in rawList) {
      if (item is Map) {
        try {
          final parsed = parser(Map<String, dynamic>.from(item));
          validItems.add(parsed);
        } catch (_) {
          // Skip corrupt individual record and recover all other valid records
        }
      }
    }
    return validItems;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'homes': homes.map((h) => h.toJson()).toList(),
        'currentHomeId': currentHomeId,
        'userProfile': userProfile.toJson(),
        'energySamples': energySamples.map((e) => e.toJson()).toList(),
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'devices': devices.map((d) {
          final json = d.toJson();
          if (json['customData'] is Map) {
            json['customData'] = _sanitizeCustomData(
                Map<String, dynamic>.from(json['customData'] as Map));
          }
          return json;
        }).toList(),
        'automations': automations.map((a) => a.toJson()).toList(),
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'activityEvents':
            activityEvents.take(100).map((e) => e.toJson()).toList(),
        'notifications':
            notifications.take(100).map((n) => n.toJson()).toList(),
        'commandRecords':
            commandRecords.take(100).map((c) => c.toJson()).toList(),
        'automationRecords':
            automationRecords.take(100).map((a) => a.toJson()).toList(),
        'deviceHealthRecords':
            deviceHealthRecords.map((h) => h.toJson()).toList(),
        'simulatedModifications': simulatedModifications,
        'dashboardConfigs':
            dashboardConfigs.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory HomeState.fromJson(Map<String, dynamic> json) {
    UserProfile userProfile = HomePersistenceManager.defaultUserProfile;
    if (json['userProfile'] is Map) {
      try {
        userProfile = UserProfile.fromJson(
            Map<String, dynamic>.from(json['userProfile'] as Map));
      } catch (_) {}
    }

    final configs = <String, DashboardConfig>{};
    if (json['dashboardConfigs'] is Map) {
      final map = json['dashboardConfigs'] as Map;
      for (final entry in map.entries) {
        if (entry.value is Map) {
          try {
            configs[entry.key.toString()] = DashboardConfig.fromJson(
                Map<String, dynamic>.from(entry.value as Map));
          } catch (_) {}
        }
      }
    }

    return HomeState(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      homes: _safeListRecovery(json['homes'], (e) => Home.fromJson(e)),
      currentHomeId: json['currentHomeId'] as String? ?? 'home-default',
      userProfile: userProfile,
      energySamples: _safeListRecovery(
          json['energySamples'], (e) => EnergySample.fromJson(e)),
      rooms: _safeListRecovery(json['rooms'], (e) => Room.fromJson(e)),
      devices:
          _safeListRecovery(json['devices'], (e) => SmartDevice.fromJson(e)),
      automations: _safeListRecovery(
          json['automations'], (e) => AutomationRule.fromJson(e)),
      scenes: _safeListRecovery(json['scenes'], (e) => Scene.fromJson(e)),
      activityEvents: _safeListRecovery(
              json['activityEvents'], (e) => ActivityEvent.fromJson(e))
          .take(100)
          .toList(),
      notifications: _safeListRecovery(
              json['notifications'], (e) => InAppNotification.fromJson(e))
          .take(100)
          .toList(),
      commandRecords: _safeListRecovery(
              json['commandRecords'], (e) => CommandRecord.fromJson(e))
          .take(100)
          .toList(),
      automationRecords: _safeListRecovery(json['automationRecords'],
          (e) => AutomationExecutionRecord.fromJson(e)).take(100).toList(),
      deviceHealthRecords: _safeListRecovery(
          json['deviceHealthRecords'], (e) => DeviceHealth.fromJson(e)),
      simulatedModifications: json['simulatedModifications'] is Map
          ? Map<String, dynamic>.from(json['simulatedModifications'] as Map)
          : const {},
      dashboardConfigs: configs,
    );
  }
}

class HomePersistenceManager {
  HomePersistenceManager({StorageAdapter? storage})
      : _storage = storage ?? StorageAdapterFactory.create();

  final StorageAdapter _storage;
  static const int schemaVersion = 6;
  static const int currentSchemaVersion = 6;
  static const String storageKey = 'lumivo_home_state_v6';
  static const String snapshotBackupKey =
      'lumivo_home_state_v6_snapshot_backup';
  static const String snapshotMetadataKey =
      'lumivo_home_state_v6_snapshot_metadata';
  static const String v5StorageKey = 'lumivo_home_state_v5';
  static const String v4StorageKey = 'lumivo_home_state_v4';
  static const String v3StorageKey = 'lumivo_home_state_v3';
  static const String v2StorageKey = 'lumivo_home_state_v2';
  static const String legacyStorageKey = 'lumivo_home_state';
  static const String snapshotStorageKey = 'lumivo_home_snapshot_v6';
  static const String lastSavedAtStorageKey = 'lumivo_last_saved_at';

  DateTime? _lastSavedAt;
  DateTime? get lastSavedAt => _lastSavedAt;

  HomeState? _cachedState;
  HomeState? get cachedState => _cachedState;

  static const List<Home> defaultHomes = [
    Home(
      id: 'home-default',
      name: 'Downtown Penthouse',
      address: '104 Lumivo Way, Penthouse 4B',
      role: 'Owner',
      isCurrent: true,
      tariffRate: 0.16,
      currency: 'USD',
    ),
    Home(
      id: 'home-suburban',
      name: 'Suburban Villa',
      address: '42 Meadow Lane',
      role: 'Owner',
      isCurrent: false,
      tariffRate: 0.14,
      currency: 'USD',
    ),
  ];

  static const UserProfile defaultUserProfile = UserProfile(
    id: 'user-01',
    name: 'Alex Mercer',
    email: 'alex.mercer@lumivo.io',
    avatarUrl: '',
    language: 'en',
    themeMode: 'dark',
    accentColor: 0xFF8B7CFF,
    reducedMotion: false,
    temperatureUnit: 'C',
  );

  static List<EnergySample> createDefaultEnergySamples() {
    final now = DateTime.now();
    final samples = <EnergySample>[];
    final hourlyWatts = [
      420.0,
      390.0,
      360.0,
      350.0,
      380.0,
      480.0,
      820.0,
      1150.0,
      920.0,
      780.0,
      740.0,
      800.0,
      880.0,
      830.0,
      760.0,
      810.0,
      1080.0,
      1420.0,
      1580.0,
      1480.0,
      1280.0,
      1020.0,
      780.0,
      580.0,
    ];
    for (int i = 0; i < 24; i++) {
      final time = now.subtract(Duration(hours: 23 - i));
      final watts = hourlyWatts[i % hourlyWatts.length];
      final kWh = watts / 1000.0;
      samples.add(
        EnergySample(
          timestamp: time,
          powerWatts: watts,
          energyKWh: double.parse(kWh.toStringAsFixed(4)),
          deviceId: 'device-ac-1',
          estimatedCost: double.parse((kWh * 0.16).toStringAsFixed(4)),
        ),
      );
    }
    return samples;
  }

  static const List<Room> defaultRooms = [
    Room(
      id: 'Living Room',
      name: 'Living Room',
      iconName: 'living_room',
      description: 'Main living space and entertainment hub',
      homeId: 'home-default',
    ),
    Room(
      id: 'Bedroom',
      name: 'Bedroom',
      iconName: 'bedroom',
      description: 'Master suite and relaxation area',
      homeId: 'home-default',
    ),
    Room(
      id: 'Kitchen',
      name: 'Kitchen',
      iconName: 'kitchen',
      description: 'Kitchen and dining space',
      homeId: 'home-default',
    ),
    Room(
      id: 'Office',
      name: 'Office',
      iconName: 'work',
      description: 'Workspace and study room',
      homeId: 'home-default',
    ),
    Room(
      id: 'Bathroom',
      name: 'Bathroom',
      iconName: 'bathroom',
      description: 'Master bathroom and shower',
      homeId: 'home-default',
    ),
    Room(
      id: 'Balcony',
      name: 'Balcony',
      iconName: 'balcony',
      description: 'Outdoor patio and balcony',
      homeId: 'home-default',
    ),
    Room(
      id: 'Garden',
      name: 'Garden',
      iconName: 'yard',
      description: 'Outdoor garden and landscape',
      homeId: 'home-suburban',
    ),
    Room(
      id: 'Garage',
      name: 'Garage',
      iconName: 'garage',
      description: 'Two-car garage and storage',
      homeId: 'home-suburban',
    ),
  ];

  static const List<SmartDevice> defaultDemoDevices = [
    SmartDevice(
      id: 'device-bulb-1',
      name: 'Smart Light',
      roomId: 'Living Room',
      type: DeviceType.light,
      isOn: true,
      brightness: 80,
      powerUsageWatts: 12.0,
      homeId: 'home-default',
      isFavorite: true,
      favoriteOrder: 1,
    ),
    SmartDevice(
      id: 'device-fan-1',
      name: 'Smart Fan',
      roomId: 'Living Room',
      type: DeviceType.fan,
      isOn: false,
      powerUsageWatts: 0.0,
      homeId: 'home-default',
      isFavorite: true,
      favoriteOrder: 2,
    ),
    SmartDevice(
      id: 'device-ac-1',
      name: 'Bedroom AC',
      roomId: 'Bedroom',
      type: DeviceType.ac,
      isOn: true,
      targetTemperature: 22.0,
      currentTemperature: 24.5,
      powerUsageWatts: 850.0,
      homeId: 'home-default',
      isFavorite: true,
      favoriteOrder: 3,
    ),
    SmartDevice(
      id: 'device-socket-1',
      name: 'Kitchen Socket',
      roomId: 'Kitchen',
      type: DeviceType.socket,
      isOn: true,
      powerUsageWatts: 120.0,
      homeId: 'home-default',
      isFavorite: false,
      favoriteOrder: 4,
    ),
    SmartDevice(
      id: 'device-curtain-1',
      name: 'Living Curtains',
      roomId: 'Living Room',
      type: DeviceType.curtain,
      isOn: true,
      position: 60,
      homeId: 'home-default',
      isFavorite: false,
      favoriteOrder: 5,
    ),
    SmartDevice(
      id: 'device-lock-1',
      name: 'Front Door Lock',
      roomId: 'Living Room',
      type: DeviceType.lock,
      isOn: true,
      isLocked: true,
      homeId: 'home-default',
      isFavorite: false,
      favoriteOrder: 6,
    ),
    SmartDevice(
      id: 'device-sensor-1',
      name: 'Climate Sensor',
      roomId: 'Bedroom',
      type: DeviceType.sensor,
      isOn: true,
      currentTemperature: 26.5,
      currentHumidity: 58.0,
      homeId: 'home-default',
      isFavorite: false,
      favoriteOrder: 7,
    ),
  ];

  static const List<SmartDevice> suburbanDemoDevices = [
    SmartDevice(
      id: 'device-villa-light',
      name: 'Garden Spotlight',
      roomId: 'Garden',
      type: DeviceType.light,
      isOn: true,
      brightness: 100,
      powerUsageWatts: 50.0,
      homeId: 'home-suburban',
      isFavorite: true,
      favoriteOrder: 1,
    ),
    SmartDevice(
      id: 'device-villa-socket',
      name: 'Garage EV Charger',
      roomId: 'Garage',
      type: DeviceType.socket,
      isOn: false,
      powerUsageWatts: 0.0,
      homeId: 'home-suburban',
      isFavorite: false,
      favoriteOrder: 2,
    ),
  ];

  static List<SmartDevice> get allDemoDevices => [
        ...defaultDemoDevices,
        ...suburbanDemoDevices,
      ];

  static const List<Scene> defaultScenes = [
    Scene(
      id: 'scene-1',
      name: 'Good Morning',
      iconName: 'wb_sunny_rounded',
      homeId: 'home-default',
      actions: [
        DeviceAction(
          deviceId: 'device-curtain-1',
          commandType: DeviceCommandType.setPosition,
          value: 100,
        ),
        DeviceAction(
          deviceId: 'device-socket-1',
          commandType: DeviceCommandType.setPower,
          value: true,
        ),
        DeviceAction(
          deviceId: 'device-ac-1',
          commandType: DeviceCommandType.setPower,
          value: false,
        ),
      ],
    ),
    Scene(
      id: 'scene-2',
      name: 'Away',
      iconName: 'logout_rounded',
      homeId: 'home-default',
      actions: [
        DeviceAction(
          deviceId: 'device-bulb-1',
          commandType: DeviceCommandType.setPower,
          value: false,
        ),
        DeviceAction(
          deviceId: 'device-lock-1',
          commandType: DeviceCommandType.setLock,
          value: true,
        ),
      ],
    ),
    Scene(
      id: 'scene-3',
      name: 'Night',
      iconName: 'nightlight_round',
      homeId: 'home-default',
      actions: [
        DeviceAction(
          deviceId: 'device-bulb-1',
          commandType: DeviceCommandType.setPower,
          value: false,
        ),
        DeviceAction(
          deviceId: 'device-fan-1',
          commandType: DeviceCommandType.setPower,
          value: false,
        ),
        DeviceAction(
          deviceId: 'device-lock-1',
          commandType: DeviceCommandType.setLock,
          value: true,
        ),
        DeviceAction(
          deviceId: 'device-curtain-1',
          commandType: DeviceCommandType.setPosition,
          value: 0,
        ),
        DeviceAction(
          deviceId: 'device-ac-1',
          commandType: DeviceCommandType.setPower,
          value: true,
        ),
      ],
    ),
    Scene(
      id: 'scene-4',
      name: 'Movie Time',
      iconName: 'movie_rounded',
      homeId: 'home-default',
      actions: [
        DeviceAction(
          deviceId: 'device-bulb-1',
          commandType: DeviceCommandType.setBrightness,
          value: 20,
        ),
        DeviceAction(
          deviceId: 'device-curtain-1',
          commandType: DeviceCommandType.setPosition,
          value: 0,
        ),
      ],
    ),
    Scene(
      id: 'scene-villa-1',
      name: 'Villa Evening',
      iconName: 'deck',
      homeId: 'home-suburban',
      actions: [
        DeviceAction(
          deviceId: 'device-villa-light',
          commandType: DeviceCommandType.setPower,
          value: true,
        ),
      ],
    ),
  ];

  static const List<AutomationRule> defaultAutomations = [
    AutomationRule(
      id: 'rule-temp-trigger',
      name: 'Auto Cool Living Room',
      isEnabled: true,
      triggerType: TriggerType.sensorThreshold,
      sensorDeviceId: 'device-sensor-1',
      sensorProperty: 'temperature',
      operator: ComparisonOperator.greaterThan,
      thresholdValue: 26.0,
      homeId: 'home-default',
      actions: [
        DeviceAction(
          deviceId: 'device-ac-1',
          commandType: DeviceCommandType.setPower,
          value: true,
        ),
        DeviceAction(
          deviceId: 'device-ac-1',
          commandType: DeviceCommandType.setTargetTemperature,
          value: 22.0,
        ),
      ],
    ),
    AutomationRule(
      id: 'rule-morning-routine',
      name: 'Morning Routine',
      isEnabled: true,
      triggerType: TriggerType.schedule,
      timeOfDay: '07:00',
      daysOfWeek: [1, 2, 3, 4, 5],
      homeId: 'home-default',
      actions: [
        DeviceAction(
          deviceId: 'device-curtain-1',
          commandType: DeviceCommandType.setPosition,
          value: 100,
        ),
        DeviceAction(
          deviceId: 'device-socket-1',
          commandType: DeviceCommandType.setPower,
          value: true,
        ),
      ],
    ),
    AutomationRule(
      id: 'rule-night-lock',
      name: 'Night Lock Guard',
      isEnabled: true,
      triggerType: TriggerType.schedule,
      timeOfDay: '23:00',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      homeId: 'home-default',
      actions: [
        DeviceAction(
          deviceId: 'device-lock-1',
          commandType: DeviceCommandType.setLock,
          value: true,
        ),
      ],
    ),
    AutomationRule(
      id: 'rule-villa-dusk',
      name: 'Villa Dusk Garden Lights',
      isEnabled: true,
      triggerType: TriggerType.schedule,
      timeOfDay: '18:30',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      homeId: 'home-suburban',
      actions: [
        DeviceAction(
          deviceId: 'device-villa-light',
          commandType: DeviceCommandType.setPower,
          value: true,
        ),
      ],
    ),
  ];

  static List<ActivityEvent> get defaultActivityEvents => [
        ActivityEvent(
          id: 'evt-init',
          title: 'System Initialized',
          description:
              'Lumivo Phase 5 state loaded with multi-home reliability, safe persistence and diagnostics',
          timestamp: DateTime.now(),
          severity: ActivitySeverity.info,
          source: 'system',
        ),
      ];

  static List<InAppNotification> get defaultNotifications => [
        InAppNotification(
          id: 'notif-welcome',
          title: 'Welcome to Lumivo',
          body:
              'Your multi-home smart ecosystem is connected and running smoothly.',
          timestamp: DateTime.now(),
          severity: ActivitySeverity.info,
        ),
      ];

  HomeState createDemoState() {
    final configs = <String, DashboardConfig>{};
    for (final home in defaultHomes) {
      configs[home.id] = DashboardConfig.defaultFor(home.id);
    }
    return HomeState(
      schemaVersion: schemaVersion,
      homes: List.of(defaultHomes),
      currentHomeId: 'home-default',
      userProfile: defaultUserProfile,
      energySamples: createDefaultEnergySamples(),
      rooms: List.of(defaultRooms),
      devices: List.of(allDemoDevices),
      automations: List.of(defaultAutomations),
      scenes: List.of(defaultScenes),
      activityEvents: defaultActivityEvents,
      notifications: defaultNotifications,
      commandRecords: const [],
      automationRecords: const [],
      deviceHealthRecords: const [],
      simulatedModifications: const {},
      dashboardConfigs: configs,
    );
  }

  Future<void> saveSnapshotBackup(HomeState state) async {
    try {
      final jsonStr = jsonEncode(state.toJson());
      await _storage.setString(snapshotBackupKey, jsonStr);
      final meta = {
        'savedAt': DateTime.now().toIso8601String(),
        'schemaVersion': state.schemaVersion,
        'deviceCount': state.devices.length,
        'homeCount': state.homes.length,
      };
      await _storage.setString(snapshotMetadataKey, jsonEncode(meta));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getSnapshotMetadata() async {
    final raw = await _storage.getString(snapshotMetadataKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> saveHomeState([HomeState? state]) async {
    final toSave = state ?? _cachedState ?? createDemoState();
    _cachedState = toSave;
    final jsonStr = jsonEncode(toSave.toJson());
    try {
      await _storage.setString(storageKey, jsonStr);
      await saveSnapshotBackup(toSave);
      _lastSavedAt = DateTime.now();
      try {
        await _storage.setString(
            lastSavedAtStorageKey, _lastSavedAt!.toIso8601String());
      } catch (_) {}
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('quota') || errStr.contains('disk')) {
        // QuotaExceededError resilience: prune historical collections down to 10 entries and retry
        final pruned = toSave.copyWith(
          activityEvents: toSave.activityEvents.take(10).toList(),
          commandRecords: toSave.commandRecords.take(10).toList(),
          automationRecords: toSave.automationRecords.take(10).toList(),
          notifications: toSave.notifications.take(10).toList(),
        );
        _cachedState = pruned;
        final prunedJson = jsonEncode(pruned.toJson());
        await _storage.setString(storageKey, prunedJson);
        await saveSnapshotBackup(pruned);
        _lastSavedAt = DateTime.now();
        try {
          await _storage.setString(
              lastSavedAtStorageKey, _lastSavedAt!.toIso8601String());
        } catch (_) {}
      } else {
        rethrow;
      }
    }
  }

  Future<HomeState> loadHomeState() async {
    try {
      if (_lastSavedAt == null) {
        try {
          final lastStr = await _storage.getString(lastSavedAtStorageKey);
          if (lastStr != null && lastStr.isNotEmpty) {
            _lastSavedAt = DateTime.tryParse(lastStr);
          }
        } catch (_) {}
      }
      var rawJson = await _storage.getString(storageKey);
      var isMigrating = false;

      if (rawJson == null || rawJson.trim().isEmpty) {
        rawJson = await _storage.getString(v5StorageKey);
        if (rawJson != null && rawJson.trim().isNotEmpty) {
          isMigrating = true;
        } else {
          rawJson = await _storage.getString(v4StorageKey);
          if (rawJson != null && rawJson.trim().isNotEmpty) {
            isMigrating = true;
          } else {
            rawJson = await _storage.getString(v3StorageKey);
            if (rawJson != null && rawJson.trim().isNotEmpty) {
              isMigrating = true;
            } else {
              rawJson = await _storage.getString(v2StorageKey);
              if (rawJson != null && rawJson.trim().isNotEmpty) {
                isMigrating = true;
              } else {
                rawJson = await _storage.getString(legacyStorageKey);
                if (rawJson != null && rawJson.trim().isNotEmpty) {
                  isMigrating = true;
                }
              }
            }
          }
        }
      }

      if (rawJson == null || rawJson.trim().isEmpty) {
        final demoState = createDemoState();
        await saveHomeState(demoState);
        return demoState;
      }

      final parsed = jsonDecode(rawJson);
      if (parsed is! Map<String, dynamic>) {
        final demoState = createDemoState();
        await saveHomeState(demoState);
        return demoState;
      }

      final version = parsed['schemaVersion'] as int? ?? 1;
      if (version < 1 || version > schemaVersion) {
        final demoState = createDemoState();
        await saveHomeState(demoState);
        return demoState;
      }
      if (version < schemaVersion || isMigrating) {
        final migratedState = _migrateToV6(parsed);
        await saveHomeState(migratedState);
        await _storage.remove(v5StorageKey);
        await _storage.remove(v4StorageKey);
        await _storage.remove(v3StorageKey);
        await _storage.remove(v2StorageKey);
        await _storage.remove(legacyStorageKey);
        return migratedState;
      }

      final state = HomeState.fromJson(parsed);
      _cachedState = state;
      return state;
    } catch (_) {
      // Robust Corrupted Storage Recovery:
      // 1. Check if snapshot backup is available for recovery
      try {
        final snapshotJson = await _storage.getString(snapshotBackupKey);
        if (snapshotJson != null && snapshotJson.trim().isNotEmpty) {
          final parsed = jsonDecode(snapshotJson);
          if (parsed is Map<String, dynamic>) {
            final recovered = HomeState.fromJson(parsed);
            _cachedState = recovered;
            await _storage.setString(storageKey, snapshotJson);
            return recovered;
          }
        }
      } catch (_) {}

      // 2. Fallback to clean factory seed state without crashing
      final demoState = createDemoState();
      try {
        await saveHomeState(demoState);
      } catch (_) {}
      return demoState;
    }
  }

  HomeState _migrateToV6(Map<String, dynamic> raw) {
    // 1. Homes: inject default homes if none present
    List<Home> homes = defaultHomes;
    if (raw['homes'] is List && (raw['homes'] as List).isNotEmpty) {
      final parsed =
          HomeState._safeListRecovery(raw['homes'], (e) => Home.fromJson(e));
      if (parsed.isNotEmpty) homes = parsed;
    }
    String currentHomeId = 'home-default';
    if (raw['currentHomeId'] is String &&
        (raw['currentHomeId'] as String).isNotEmpty) {
      currentHomeId = raw['currentHomeId'] as String;
    }

    // 2. Devices: preserve isFavorite, favoriteOrder, customIcon, and tag homeId
    List<SmartDevice> devices = allDemoDevices;
    if (raw['devices'] is List && (raw['devices'] as List).isNotEmpty) {
      final parsed = HomeState._safeListRecovery(raw['devices'], (e) {
        final devJson = Map<String, dynamic>.from(e);
        if (devJson['homeId'] == null ||
            (devJson['homeId'] as String).isEmpty) {
          devJson['homeId'] = 'home-default';
        }
        if (devJson['customData'] is Map) {
          devJson['customData'] = HomeState._sanitizeCustomData(
              Map<String, dynamic>.from(devJson['customData'] as Map));
        }
        return SmartDevice.fromJson(devJson);
      });
      if (parsed.isNotEmpty) devices = parsed;
    }

    // 3. Rooms: tag homeId
    List<Room> rooms = defaultRooms;
    if (raw['rooms'] is List && (raw['rooms'] as List).isNotEmpty) {
      final parsed = HomeState._safeListRecovery(raw['rooms'], (e) {
        final roomJson = Map<String, dynamic>.from(e);
        if (roomJson['homeId'] == null ||
            (roomJson['homeId'] as String).isEmpty) {
          roomJson['homeId'] = 'home-default';
        }
        return Room.fromJson(roomJson);
      });
      if (parsed.isNotEmpty) rooms = parsed;
    }

    // 4. Scenes: tag homeId
    List<Scene> scenes = defaultScenes;
    if (raw['scenes'] is List && (raw['scenes'] as List).isNotEmpty) {
      final parsed = HomeState._safeListRecovery(raw['scenes'], (e) {
        final scJson = Map<String, dynamic>.from(e);
        if (scJson['homeId'] == null || (scJson['homeId'] as String).isEmpty) {
          scJson['homeId'] = 'home-default';
        }
        return Scene.fromJson(scJson);
      });
      if (parsed.isNotEmpty) scenes = parsed;
    }

    // 5. Automations: tag homeId
    List<AutomationRule> automations = defaultAutomations;
    if (raw['automations'] is List && (raw['automations'] as List).isNotEmpty) {
      final parsed = HomeState._safeListRecovery(raw['automations'], (e) {
        final autoJson = Map<String, dynamic>.from(e);
        if (autoJson['homeId'] == null ||
            (autoJson['homeId'] as String).isEmpty) {
          autoJson['homeId'] = 'home-default';
        }
        return AutomationRule.fromJson(autoJson);
      });
      if (parsed.isNotEmpty) automations = parsed;
    }

    // 6. UserProfile: add default if not present
    UserProfile userProfile = defaultUserProfile;
    if (raw['userProfile'] is Map<String, dynamic>) {
      try {
        userProfile =
            UserProfile.fromJson(raw['userProfile'] as Map<String, dynamic>);
      } catch (_) {}
    }

    // 7. Energy samples: add initial if not present
    List<EnergySample> energySamples = createDefaultEnergySamples();
    if (raw['energySamples'] is List &&
        (raw['energySamples'] as List).isNotEmpty) {
      final parsed = HomeState._safeListRecovery(
          raw['energySamples'], (e) => EnergySample.fromJson(e));
      if (parsed.isNotEmpty) energySamples = parsed;
    }

    // 8. Activity events
    List<ActivityEvent> events = defaultActivityEvents;
    if (raw['activityEvents'] is List &&
        (raw['activityEvents'] as List).isNotEmpty) {
      final parsed = HomeState._safeListRecovery(
              raw['activityEvents'], (e) => ActivityEvent.fromJson(e))
          .take(100)
          .toList();
      if (parsed.isNotEmpty) events = parsed;
    }

    // 9. Notifications
    List<InAppNotification> notifs = defaultNotifications;
    if (raw['notifications'] is List &&
        (raw['notifications'] as List).isNotEmpty) {
      final parsed = HomeState._safeListRecovery(
              raw['notifications'], (e) => InAppNotification.fromJson(e))
          .take(100)
          .toList();
      if (parsed.isNotEmpty) notifs = parsed;
    }

    // 10. Phase 5: Command Records (bounded up to 100)
    List<CommandRecord> commandRecords = const [];
    if (raw['commandRecords'] is List &&
        (raw['commandRecords'] as List).isNotEmpty) {
      commandRecords = HomeState._safeListRecovery(
              raw['commandRecords'], (e) => CommandRecord.fromJson(e))
          .take(100)
          .toList();
    }

    // 11. Phase 5: Automation Records (bounded up to 100)
    List<AutomationExecutionRecord> automationRecords = const [];
    if (raw['automationRecords'] is List &&
        (raw['automationRecords'] as List).isNotEmpty) {
      automationRecords = HomeState._safeListRecovery(raw['automationRecords'],
          (e) => AutomationExecutionRecord.fromJson(e)).take(100).toList();
    }

    // 12. Phase 5: Device Health Records
    List<DeviceHealth> deviceHealthRecords = const [];
    if (raw['deviceHealthRecords'] is List &&
        (raw['deviceHealthRecords'] as List).isNotEmpty) {
      deviceHealthRecords = HomeState._safeListRecovery(
          raw['deviceHealthRecords'], (e) => DeviceHealth.fromJson(e));
    }

    // 13. Phase 5: Simulated Modifications
    Map<String, dynamic> simMods = const {};
    if (raw['simulatedModifications'] is Map) {
      simMods = Map<String, dynamic>.from(raw['simulatedModifications'] as Map);
    }

    // 14. Phase 6: Dashboard Configs per home
    final Map<String, DashboardConfig> dashboardConfigs = {};
    if (raw['dashboardConfigs'] is Map &&
        (raw['dashboardConfigs'] as Map).isNotEmpty) {
      final map = raw['dashboardConfigs'] as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v is Map) {
          try {
            dashboardConfigs[k] =
                DashboardConfig.fromJson(Map<String, dynamic>.from(v));
          } catch (_) {}
        }
      });
    }
    for (final home in homes) {
      dashboardConfigs.putIfAbsent(
        home.id,
        () => DashboardConfig.defaultFor(home.id),
      );
    }

    return HomeState(
      schemaVersion: schemaVersion,
      homes: homes,
      currentHomeId: currentHomeId,
      userProfile: userProfile,
      energySamples: energySamples,
      rooms: rooms,
      devices: devices,
      automations: automations,
      scenes: scenes,
      activityEvents: events,
      notifications: notifs,
      commandRecords: commandRecords,
      automationRecords: automationRecords,
      deviceHealthRecords: deviceHealthRecords,
      simulatedModifications: simMods,
      dashboardConfigs: dashboardConfigs,
    );
  }

  Future<HomeState> resetDemoData() async {
    await _storage.remove(storageKey);
    await _storage.remove(v5StorageKey);
    await _storage.remove(v4StorageKey);
    await _storage.remove(v3StorageKey);
    await _storage.remove(v2StorageKey);
    await _storage.remove(legacyStorageKey);
    final demoState = createDemoState();
    await saveHomeState(demoState);
    return demoState;
  }

  Future<void> saveSnapshot([HomeState? state]) async {
    final toSave = state ?? _cachedState ?? await loadHomeState();
    final jsonStr = jsonEncode(toSave.toJson());
    await _storage.setString(snapshotStorageKey, jsonStr);
  }

  Future<bool> hasSnapshot() async {
    final raw = await _storage.getString(snapshotStorageKey);
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>;
    } catch (_) {
      return false;
    }
  }

  Future<HomeState?> loadSnapshot() async {
    try {
      final raw = await _storage.getString(snapshotStorageKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return HomeState.fromJson(parsed);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> restoreSnapshot() async {
    final snapshot = await loadSnapshot();
    if (snapshot == null) return false;
    await saveHomeState(snapshot);
    return true;
  }

  int getApproximateStorageSizeBytes([HomeState? state]) {
    final current = state ?? _cachedState ?? createDemoState();
    final jsonStr = jsonEncode(current.toJson());
    return utf8.encode(jsonStr).length;
  }

  Future<HomeState> _getCurrentOrFallback() async {
    if (_cachedState != null) return _cachedState!;
    final raw = await _storage.getString(storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          final state = HomeState.fromJson(parsed);
          _cachedState = state;
          return state;
        }
      } catch (_) {}
    }
    return _cachedState ?? createDemoState();
  }

  Future<void> saveHomes(List<Home> homes) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(homes: homes));
  }

  Future<void> saveCurrentHomeId(String currentHomeId) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(currentHomeId: currentHomeId));
  }

  Future<void> saveUserProfile(UserProfile userProfile) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(userProfile: userProfile));
  }

  Future<void> saveEnergySamples(List<EnergySample> energySamples) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(energySamples: energySamples));
  }

  Future<void> saveDevices(List<SmartDevice> devices) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(devices: devices));
  }

  Future<void> saveRooms(List<Room> rooms) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(rooms: rooms));
  }

  Future<void> saveAutomations(List<AutomationRule> automations) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(automations: automations));
  }

  Future<void> saveScenes(List<Scene> scenes) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(scenes: scenes));
  }

  Future<void> saveActivityEvents(List<ActivityEvent> events) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(
        current.copyWith(activityEvents: events.take(100).toList()));
  }

  Future<void> saveNotifications(List<InAppNotification> notifications) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(
        current.copyWith(notifications: notifications.take(100).toList()));
  }

  List<CommandRecord> getCommandRecords({String? homeId}) {
    final state = _cachedState ?? createDemoState();
    if (homeId == null) {
      return List.unmodifiable(state.commandRecords.take(100));
    }
    return List.unmodifiable(
        state.commandRecords.where((r) => r.homeId == homeId).take(100));
  }

  Future<void> saveCommandRecords(
    List<CommandRecord> records, {
    String? homeId,
  }) async {
    final current = await _getCurrentOrFallback();
    final List<CommandRecord> merged;
    if (homeId != null) {
      final otherHomeRecords =
          current.commandRecords.where((r) => r.homeId != homeId).toList();
      final targetHomeRecords =
          records.where((r) => r.homeId == homeId).take(100).toList();
      merged = [...targetHomeRecords, ...otherHomeRecords].take(200).toList();
    } else {
      merged = records.take(100).toList();
    }
    await saveHomeState(current.copyWith(commandRecords: merged));
  }

  List<AutomationExecutionRecord> getAutomationRecords({String? homeId}) {
    final state = _cachedState ?? createDemoState();
    if (homeId == null) {
      return List.unmodifiable(state.automationRecords.take(100));
    }
    return List.unmodifiable(
        state.automationRecords.where((r) => r.homeId == homeId).take(100));
  }

  Future<void> saveAutomationRecords(
    List<AutomationExecutionRecord> records, {
    String? homeId,
  }) async {
    final current = await _getCurrentOrFallback();
    final List<AutomationExecutionRecord> merged;
    if (homeId != null) {
      final otherHomeRecords =
          current.automationRecords.where((r) => r.homeId != homeId).toList();
      final targetHomeRecords =
          records.where((r) => r.homeId == homeId).take(100).toList();
      merged = [...targetHomeRecords, ...otherHomeRecords].take(200).toList();
    } else {
      merged = records.take(100).toList();
    }
    await saveHomeState(current.copyWith(automationRecords: merged));
  }

  List<DeviceHealth> getDeviceHealthRecords({String? homeId}) {
    final state = _cachedState ?? createDemoState();
    if (homeId == null) {
      return List.unmodifiable(state.deviceHealthRecords);
    }
    return List.unmodifiable(
        state.deviceHealthRecords.where((h) => h.homeId == homeId));
  }

  Future<void> saveDeviceHealthRecords(
    List<DeviceHealth> healthList, {
    String? homeId,
  }) async {
    final current = await _getCurrentOrFallback();
    final List<DeviceHealth> merged;
    if (homeId != null) {
      final other =
          current.deviceHealthRecords.where((h) => h.homeId != homeId).toList();
      final target = healthList.where((h) => h.homeId == homeId).toList();
      merged = [...target, ...other];
    } else {
      merged = List.of(healthList);
    }
    await saveHomeState(current.copyWith(deviceHealthRecords: merged));
  }

  Future<void> saveSimulatedModifications(Map<String, dynamic> mods) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(simulatedModifications: mods));
  }

  DashboardConfig getDashboardConfig(String homeId) {
    final state = _cachedState ?? createDemoState();
    return state.dashboardConfigs[homeId] ?? DashboardConfig.defaultFor(homeId);
  }

  Future<void> saveDashboardConfig(DashboardConfig config) async {
    final current = await _getCurrentOrFallback();
    final updated = Map<String, DashboardConfig>.from(current.dashboardConfigs);
    updated[config.homeId] = config;
    await saveHomeState(current.copyWith(dashboardConfigs: updated));
  }

  Future<void> deleteDeviceWithCascade(String deviceId) async {
    final current = await _getCurrentOrFallback();
    final index = current.devices.indexWhere((d) => d.id == deviceId);
    if (index < 0) return;

    final removedDevice = current.devices[index];
    final updatedDevices = List<SmartDevice>.from(current.devices)
      ..removeAt(index);

    // Prune and re-index favorites
    final favs = updatedDevices.where((d) => d.isFavorite).toList()
      ..sort((a, b) => a.favoriteOrder.compareTo(b.favoriteOrder));
    for (int i = 0; i < favs.length; i++) {
      final devIdx = updatedDevices.indexWhere((d) => d.id == favs[i].id);
      if (devIdx >= 0) {
        updatedDevices[devIdx] =
            updatedDevices[devIdx].copyWith(favoriteOrder: i);
      }
    }

    // Prune actions from Scenes
    final updatedScenes = current.scenes.map((scene) {
      final prunedActions =
          scene.actions.where((action) => action.deviceId != deviceId).toList();
      return scene.copyWith(actions: prunedActions);
    }).toList();

    // Prune or disable AutomationRules
    final updatedRules = current.automations.map((rule) {
      final isSensorRef = rule.sensorDeviceId == deviceId;
      final prunedActions =
          rule.actions.where((action) => action.deviceId != deviceId).toList();
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

    // Cascade Event
    final cascadeEvent = ActivityEvent(
      id: 'evt-cascade-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Cascade Deletion: ${removedDevice.name}',
      description:
          'Device "$deviceId" removed. Pruned from scenes and automations.',
      timestamp: DateTime.now(),
      deviceId: deviceId,
      homeId: removedDevice.homeId,
      severity: ActivitySeverity.warning,
      source: 'system',
    );

    final updatedEvents =
        [cascadeEvent, ...current.activityEvents].take(100).toList();

    await saveHomeState(current.copyWith(
      devices: updatedDevices,
      scenes: updatedScenes,
      automations: updatedRules,
      activityEvents: updatedEvents,
    ));
  }

  Future<void> deleteRoomWithCascade(String roomId,
      {String? reassignToRoomId}) async {
    final current = await _getCurrentOrFallback();
    final roomIdx = current.rooms.indexWhere((r) => r.id == roomId);
    if (roomIdx < 0) return;

    final targetRoom = current.rooms[roomIdx];
    final remainingRooms = List<Room>.from(current.rooms)..removeAt(roomIdx);

    // Reassign or remove associated devices
    String? fallbackRoomId = reassignToRoomId;
    if (fallbackRoomId == null) {
      final otherRoomsInHome =
          remainingRooms.where((r) => r.homeId == targetRoom.homeId).toList();
      if (otherRoomsInHome.isNotEmpty) {
        fallbackRoomId = otherRoomsInHome.first.id;
      }
    }

    final updatedDevices = current.devices
        .map((d) {
          if (d.roomId == roomId) {
            if (fallbackRoomId != null) {
              return d.copyWith(roomId: fallbackRoomId);
            }
          }
          return d;
        })
        .where((d) => fallbackRoomId != null || d.roomId != roomId)
        .toList();

    final cascadeEvent = ActivityEvent(
      id: 'evt-room-cascade-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Room Deleted: ${targetRoom.name}',
      description: fallbackRoomId != null
          ? 'Room "$roomId" removed. Devices reassigned to "$fallbackRoomId".'
          : 'Room "$roomId" removed. Associated devices removed.',
      timestamp: DateTime.now(),
      homeId: targetRoom.homeId,
      severity: ActivitySeverity.warning,
      source: 'system',
    );

    final updatedEvents =
        [cascadeEvent, ...current.activityEvents].take(100).toList();

    await saveHomeState(current.copyWith(
      rooms: remainingRooms,
      devices: updatedDevices,
      activityEvents: updatedEvents,
    ));
  }

  Future<void> deleteHomeWithCascade(String homeId) async {
    final current = await _getCurrentOrFallback();
    final remainingHomes = current.homes.where((h) => h.id != homeId).toList();

    var nextCurrentId = current.currentHomeId;
    if (current.currentHomeId == homeId) {
      if (remainingHomes.any((h) => h.id == 'home-default')) {
        nextCurrentId = 'home-default';
      } else if (remainingHomes.isNotEmpty) {
        nextCurrentId = remainingHomes.first.id;
      } else {
        nextCurrentId = 'home-default';
      }
    }

    final updatedHomes = remainingHomes
        .map((h) => h.copyWith(isCurrent: h.id == nextCurrentId))
        .toList();

    final updatedDevices =
        current.devices.where((d) => d.homeId != homeId).toList();
    final updatedRooms =
        current.rooms.where((r) => r.homeId != homeId).toList();
    final updatedScenes =
        current.scenes.where((s) => s.homeId != homeId).toList();
    final updatedAutomations =
        current.automations.where((a) => a.homeId != homeId).toList();
    final updatedDashboardConfigs =
        Map<String, DashboardConfig>.from(current.dashboardConfigs)
          ..remove(homeId);
    final updatedHealth =
        current.deviceHealthRecords.where((h) => h.homeId != homeId).toList();
    final updatedCommands =
        current.commandRecords.where((c) => c.homeId != homeId).toList();
    final updatedAutoRecords =
        current.automationRecords.where((a) => a.homeId != homeId).toList();
    final updatedEvents = current.activityEvents
        .where((e) => e.homeId != homeId)
        .take(100)
        .toList();
    final updatedNotifs = current.notifications
        .where((n) => n.homeId != homeId)
        .take(100)
        .toList();

    final cascadeEvent = ActivityEvent(
      id: 'evt-home-cascade-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Home Deleted: $homeId',
      description:
          'Home "$homeId" and all home-scoped data were purged cleanly.',
      timestamp: DateTime.now(),
      severity: ActivitySeverity.warning,
      source: 'system',
    );

    await saveHomeState(current.copyWith(
      homes: updatedHomes,
      currentHomeId: nextCurrentId,
      devices: updatedDevices,
      rooms: updatedRooms,
      scenes: updatedScenes,
      automations: updatedAutomations,
      dashboardConfigs: updatedDashboardConfigs,
      deviceHealthRecords: updatedHealth,
      commandRecords: updatedCommands,
      automationRecords: updatedAutoRecords,
      activityEvents: [cascadeEvent, ...updatedEvents].take(100).toList(),
      notifications: updatedNotifs,
    ));
  }

  static const String firstRunStorageKey = 'lumivo_first_run_completed';

  Future<bool> isFirstRunCompleted() async {
    final val = await _storage.getString(firstRunStorageKey);
    return val == 'true';
  }

  Future<void> setFirstRunCompleted(bool completed) async {
    await _storage.setString(firstRunStorageKey, completed.toString());
  }
}

final homePersistenceProvider = Provider<HomePersistenceManager>((ref) {
  return HomePersistenceManager();
});
