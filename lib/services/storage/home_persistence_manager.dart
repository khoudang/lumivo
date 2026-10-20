import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/activity_event.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/device_command.dart';
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
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'homes': homes.map((h) => h.toJson()).toList(),
        'currentHomeId': currentHomeId,
        'userProfile': userProfile.toJson(),
        'energySamples': energySamples.map((e) => e.toJson()).toList(),
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
      homes: (json['homes'] as List<dynamic>?)
              ?.map((e) => Home.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      currentHomeId: json['currentHomeId'] as String? ?? 'home-default',
      userProfile: json['userProfile'] is Map<String, dynamic>
          ? UserProfile.fromJson(json['userProfile'] as Map<String, dynamic>)
          : HomePersistenceManager.defaultUserProfile,
      energySamples: (json['energySamples'] as List<dynamic>?)
              ?.map((e) => EnergySample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
  static const int schemaVersion = 3;
  static const int currentSchemaVersion = 3;
  static const String storageKey = 'lumivo_home_state_v3';
  static const String v2StorageKey = 'lumivo_home_state_v2';
  static const String legacyStorageKey = 'lumivo_home_state';

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
              'Lumivo Phase 3 state loaded with 9 devices across 2 homes',
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
      var isMigrating = false;

      if (rawJson == null || rawJson.trim().isEmpty) {
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
      if (version < schemaVersion || isMigrating) {
        final migratedState = _migrateToV3(parsed);
        await saveHomeState(migratedState);
        await _storage.remove(v2StorageKey);
        await _storage.remove(legacyStorageKey);
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

  HomeState _migrateToV3(Map<String, dynamic> raw) {
    // 1. Homes: inject default homes if none present
    List<Home> homes = defaultHomes;
    if (raw['homes'] is List && (raw['homes'] as List).isNotEmpty) {
      homes = (raw['homes'] as List)
          .map((e) => Home.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    String currentHomeId = 'home-default';
    if (raw['currentHomeId'] is String &&
        (raw['currentHomeId'] as String).isNotEmpty) {
      currentHomeId = raw['currentHomeId'] as String;
    }

    // 2. Devices: preserve isFavorite, favoriteOrder, customIcon, and tag homeId
    List<SmartDevice> devices = allDemoDevices;
    if (raw['devices'] is List && (raw['devices'] as List).isNotEmpty) {
      devices = (raw['devices'] as List).map((e) {
        final devJson = Map<String, dynamic>.from(e as Map<String, dynamic>);
        if (devJson['homeId'] == null ||
            (devJson['homeId'] as String).isEmpty) {
          devJson['homeId'] = 'home-default';
        }
        return SmartDevice.fromJson(devJson);
      }).toList();
    }

    // 3. Rooms: tag homeId
    List<Room> rooms = defaultRooms;
    if (raw['rooms'] is List && (raw['rooms'] as List).isNotEmpty) {
      rooms = (raw['rooms'] as List).map((e) {
        final roomJson = Map<String, dynamic>.from(e as Map<String, dynamic>);
        if (roomJson['homeId'] == null ||
            (roomJson['homeId'] as String).isEmpty) {
          roomJson['homeId'] = 'home-default';
        }
        return Room.fromJson(roomJson);
      }).toList();
    }

    // 4. Scenes: tag homeId
    List<Scene> scenes = defaultScenes;
    if (raw['scenes'] is List && (raw['scenes'] as List).isNotEmpty) {
      scenes = (raw['scenes'] as List).map((e) {
        final scJson = Map<String, dynamic>.from(e as Map<String, dynamic>);
        if (scJson['homeId'] == null || (scJson['homeId'] as String).isEmpty) {
          scJson['homeId'] = 'home-default';
        }
        return Scene.fromJson(scJson);
      }).toList();
    }

    // 5. Automations: tag homeId
    List<AutomationRule> automations = defaultAutomations;
    if (raw['automations'] is List && (raw['automations'] as List).isNotEmpty) {
      automations = (raw['automations'] as List).map((e) {
        final autoJson = Map<String, dynamic>.from(e as Map<String, dynamic>);
        if (autoJson['homeId'] == null ||
            (autoJson['homeId'] as String).isEmpty) {
          autoJson['homeId'] = 'home-default';
        }
        return AutomationRule.fromJson(autoJson);
      }).toList();
    }

    // 6. UserProfile: add default if not present
    UserProfile userProfile = defaultUserProfile;
    if (raw['userProfile'] is Map<String, dynamic>) {
      userProfile =
          UserProfile.fromJson(raw['userProfile'] as Map<String, dynamic>);
    }

    // 7. Energy samples: add initial if not present
    List<EnergySample> energySamples = createDefaultEnergySamples();
    if (raw['energySamples'] is List &&
        (raw['energySamples'] as List).isNotEmpty) {
      energySamples = (raw['energySamples'] as List)
          .map((e) => EnergySample.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 8. Activity events
    List<ActivityEvent> events = defaultActivityEvents;
    if (raw['activityEvents'] is List &&
        (raw['activityEvents'] as List).isNotEmpty) {
      events = (raw['activityEvents'] as List)
          .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 9. Notifications
    List<InAppNotification> notifs = defaultNotifications;
    if (raw['notifications'] is List &&
        (raw['notifications'] as List).isNotEmpty) {
      notifs = (raw['notifications'] as List)
          .map((e) => InAppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
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
    );
  }

  Future<HomeState> resetDemoData() async {
    await _storage.remove(storageKey);
    await _storage.remove(v2StorageKey);
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
