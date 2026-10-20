import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/activity_event.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/device_command.dart';
import '../../core/models/in_app_notification.dart';
import '../../core/models/room.dart';
import '../../core/models/smart_device.dart';
import 'storage_adapter.dart';
import 'storage_adapter_factory.dart';

class HomeState {
  const HomeState({
    this.schemaVersion = HomePersistenceManager.currentSchemaVersion,
    this.rooms = const [],
    this.devices = const [],
    this.automations = const [],
    this.scenes = const [],
    this.activityEvents = const [],
    this.notifications = const [],
  });

  final int schemaVersion;
  final List<Room> rooms;
  final List<SmartDevice> devices;
  final List<AutomationRule> automations;
  final List<Scene> scenes;
  final List<ActivityEvent> activityEvents;
  final List<InAppNotification> notifications;

  HomeState copyWith({
    int? schemaVersion,
    List<Room>? rooms,
    List<SmartDevice>? devices,
    List<AutomationRule>? automations,
    List<Scene>? scenes,
    List<ActivityEvent>? activityEvents,
    List<InAppNotification>? notifications,
  }) {
    return HomeState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      rooms: rooms ?? this.rooms,
      devices: devices ?? this.devices,
      automations: automations ?? this.automations,
      scenes: scenes ?? this.scenes,
      activityEvents: activityEvents ?? this.activityEvents,
      notifications: notifications ?? this.notifications,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'devices': devices.map((d) => d.toJson()).toList(),
        'automations': automations.map((a) => a.toJson()).toList(),
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'activityEvents': activityEvents.map((e) => e.toJson()).toList(),
        'notifications': notifications.map((n) => n.toJson()).toList(),
      };

  factory HomeState.fromJson(Map<String, dynamic> json) {
    return HomeState(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      rooms: (json['rooms'] as List<dynamic>?)
              ?.map((e) => Room.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      devices: (json['devices'] as List<dynamic>?)
              ?.map((e) => SmartDevice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      automations: (json['automations'] as List<dynamic>?)
              ?.map((e) => AutomationRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      scenes: (json['scenes'] as List<dynamic>?)
              ?.map((e) => Scene.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      activityEvents: (json['activityEvents'] as List<dynamic>?)
              ?.map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map(
                  (e) => InAppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class HomePersistenceManager {
  HomePersistenceManager({StorageAdapter? storage})
      : _storage = storage ?? StorageAdapterFactory.create();

  final StorageAdapter _storage;
  static const int currentSchemaVersion = 2;
  static const String storageKey = 'lumivo_home_state_v2';
  static const String legacyStorageKey = 'lumivo_home_state';

  HomeState? _cachedState;
  HomeState? get cachedState => _cachedState;

  static const List<Room> defaultRooms = [
    Room(
      id: 'Living Room',
      name: 'Living Room',
      iconName: 'living_room',
      description: 'Main living space and entertainment hub',
    ),
    Room(
      id: 'Bedroom',
      name: 'Bedroom',
      iconName: 'bedroom',
      description: 'Master suite and relaxation area',
    ),
    Room(
      id: 'Kitchen',
      name: 'Kitchen',
      iconName: 'kitchen',
      description: 'Kitchen and dining space',
    ),
    Room(
      id: 'Office',
      name: 'Office',
      iconName: 'work',
      description: 'Workspace and study room',
    ),
    Room(
      id: 'Bathroom',
      name: 'Bathroom',
      iconName: 'bathroom',
      description: 'Master bathroom and shower',
    ),
    Room(
      id: 'Balcony',
      name: 'Balcony',
      iconName: 'balcony',
      description: 'Outdoor patio and balcony',
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
    ),
    SmartDevice(
      id: 'device-fan-1',
      name: 'Smart Fan',
      roomId: 'Living Room',
      type: DeviceType.fan,
      isOn: false,
      powerUsageWatts: 0.0,
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
    ),
    SmartDevice(
      id: 'device-socket-1',
      name: 'Kitchen Socket',
      roomId: 'Kitchen',
      type: DeviceType.socket,
      isOn: true,
      powerUsageWatts: 120.0,
    ),
    SmartDevice(
      id: 'device-curtain-1',
      name: 'Living Curtains',
      roomId: 'Living Room',
      type: DeviceType.curtain,
      isOn: true,
      position: 60,
    ),
    SmartDevice(
      id: 'device-lock-1',
      name: 'Front Door Lock',
      roomId: 'Living Room',
      type: DeviceType.lock,
      isOn: true,
      isLocked: true,
    ),
    SmartDevice(
      id: 'device-sensor-1',
      name: 'Climate Sensor',
      roomId: 'Bedroom',
      type: DeviceType.sensor,
      isOn: true,
      currentTemperature: 26.5,
      currentHumidity: 58.0,
    ),
  ];

  static const List<Scene> defaultScenes = [
    Scene(
      id: 'scene-1',
      name: 'Good Morning',
      iconName: 'wb_sunny_rounded',
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
      actions: [
        DeviceAction(
          deviceId: 'device-lock-1',
          commandType: DeviceCommandType.setLock,
          value: true,
        ),
      ],
    ),
  ];

  static List<ActivityEvent> get defaultActivityEvents => [
        ActivityEvent(
          id: 'evt-init',
          title: 'System Initialized',
          description: 'Demo home state loaded with 7 devices across 4 rooms',
          timestamp: DateTime.now(),
          severity: ActivitySeverity.info,
          source: 'system',
        ),
      ];

  static List<InAppNotification> get defaultNotifications => [
        InAppNotification(
          id: 'notif-welcome',
          title: 'Welcome to Lumivo',
          body: 'Your smart home is connected and running smoothly.',
          timestamp: DateTime.now(),
          severity: ActivitySeverity.info,
        ),
      ];

  HomeState createDemoState() {
    return HomeState(
      schemaVersion: currentSchemaVersion,
      rooms: List.of(defaultRooms),
      devices: List.of(defaultDemoDevices),
      automations: List.of(defaultAutomations),
      scenes: List.of(defaultScenes),
      activityEvents: defaultActivityEvents,
      notifications: defaultNotifications,
    );
  }

  Future<void> saveHomeState([HomeState? state]) async {
    final toSave = state ?? _cachedState ?? createDemoState();
    _cachedState = toSave;
    final jsonStr = jsonEncode(toSave.toJson());
    await _storage.setString(storageKey, jsonStr);
  }

  Future<HomeState> loadHomeState() async {
    try {
      var rawJson = await _storage.getString(storageKey);
      var isLegacy = false;

      if (rawJson == null || rawJson.trim().isEmpty) {
        rawJson = await _storage.getString(legacyStorageKey);
        if (rawJson != null && rawJson.trim().isNotEmpty) {
          isLegacy = true;
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
      if (version < currentSchemaVersion || isLegacy) {
        final migratedState = _migratePhase1ToPhase2(parsed);
        await saveHomeState(migratedState);
        if (isLegacy) {
          await _storage.remove(legacyStorageKey);
        }
        return migratedState;
      }

      final state = HomeState.fromJson(parsed);
      _cachedState = state;
      return state;
    } catch (_) {
      final demoState = createDemoState();
      await saveHomeState(demoState);
      return demoState;
    }
  }

  HomeState _migratePhase1ToPhase2(Map<String, dynamic> legacy) {
    List<Room> rooms = defaultRooms;
    if (legacy['rooms'] is List && (legacy['rooms'] as List).isNotEmpty) {
      rooms = (legacy['rooms'] as List)
          .map((e) => Room.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<SmartDevice> devices = defaultDemoDevices;
    if (legacy['devices'] is List && (legacy['devices'] as List).isNotEmpty) {
      devices = (legacy['devices'] as List)
          .map((e) => SmartDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<AutomationRule> automations = defaultAutomations;
    if (legacy['automations'] is List &&
        (legacy['automations'] as List).isNotEmpty) {
      automations = (legacy['automations'] as List)
          .map((e) => AutomationRule.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<Scene> scenes = defaultScenes;
    if (legacy['scenes'] is List && (legacy['scenes'] as List).isNotEmpty) {
      scenes = (legacy['scenes'] as List)
          .map((e) => Scene.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<ActivityEvent> events = defaultActivityEvents;
    if (legacy['activityEvents'] is List) {
      events = (legacy['activityEvents'] as List)
          .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<InAppNotification> notifs = defaultNotifications;
    if (legacy['notifications'] is List) {
      notifs = (legacy['notifications'] as List)
          .map((e) => InAppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return HomeState(
      schemaVersion: currentSchemaVersion,
      rooms: rooms,
      devices: devices,
      automations: automations,
      scenes: scenes,
      activityEvents: events,
      notifications: notifs,
    );
  }

  Future<HomeState> resetDemoData() async {
    await _storage.remove(storageKey);
    await _storage.remove(legacyStorageKey);
    final demoState = createDemoState();
    await saveHomeState(demoState);
    return demoState;
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
    await saveHomeState(current.copyWith(activityEvents: events));
  }

  Future<void> saveNotifications(List<InAppNotification> notifications) async {
    final current = await _getCurrentOrFallback();
    await saveHomeState(current.copyWith(notifications: notifications));
  }
}

final homePersistenceProvider = Provider<HomePersistenceManager>((ref) {
  return HomePersistenceManager();
});
