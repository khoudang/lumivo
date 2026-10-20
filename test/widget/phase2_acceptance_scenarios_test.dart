import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/in_app_notification.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/activity/state/activity_notifier.dart';
import 'package:lumivo/features/automation/state/automation_notifier.dart';
import 'package:lumivo/features/notifications/state/notifications_notifier.dart';
import 'package:lumivo/features/rooms/state/rooms_notifier.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 2 Acceptance Scenarios', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistence;
    late MockDeviceRepository repository;
    late RoomsNotifier roomsNotifier;
    late AutomationNotifier automationNotifier;
    late ActivityNotifier activityNotifier;
    late NotificationsNotifier notificationsNotifier;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistence = HomePersistenceManager(storage: storage);
      await persistence.resetDemoData();

      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: HomePersistenceManager.defaultDemoDevices,
        persistenceManager: persistence,
      );

      roomsNotifier = RoomsNotifier(
        List.of(HomePersistenceManager.defaultRooms),
        persistence,
      );

      automationNotifier = AutomationNotifier(
        List.of(HomePersistenceManager.defaultAutomations),
        persistence,
      );

      activityNotifier = ActivityNotifier(
        persistence.cachedState?.activityEvents,
        persistence,
      );

      notificationsNotifier = NotificationsNotifier(
        persistence.cachedState?.notifications,
        persistence,
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    test(
        'Scenario 1: Create room -> add simulated device -> control it -> verify state persistence',
        () async {
      // 1. Create a new room
      const newRoom = Room(
        id: 'balcony-room',
        name: 'Balcony',
        iconName: 'deck',
        description: 'Outdoor relaxation zone',
      );
      await roomsNotifier.addRoom(newRoom);
      expect(roomsNotifier.state.any((r) => r.id == 'balcony-room'), isTrue);

      // 2. Add simulated device to the new room
      const balconyBulb = SmartDevice(
        id: 'balcony-bulb-1',
        name: 'Balcony Fairy Lights',
        roomId: 'balcony-room',
        type: DeviceType.light,
        isOn: false,
        brightness: 0,
      );
      repository.addDevice(balconyBulb);
      expect(
        repository.devices.any((d) => d.id == 'balcony-bulb-1'),
        isTrue,
      );

      // 3. Control the simulated device
      final cmdResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'sc1-cmd-power',
          deviceId: 'balcony-bulb-1',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(cmdResult.status, CommandStatus.confirmed);

      final brightResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'sc1-cmd-brightness',
          deviceId: 'balcony-bulb-1',
          type: DeviceCommandType.setBrightness,
          value: 85,
        ),
      );
      expect(brightResult.status, CommandStatus.confirmed);

      final updatedInRepo =
          repository.devices.firstWhere((d) => d.id == 'balcony-bulb-1');
      expect(updatedInRepo.isOn, isTrue);
      expect(updatedInRepo.brightness, 85);

      // 4. Verify state persistence across full home state reload
      final persistedState = await persistence.loadHomeState();

      // Verify room persisted
      expect(
        persistedState.rooms.any((r) => r.id == 'balcony-room'),
        isTrue,
      );
      // Verify device and modified control state persisted
      final persistedDevice =
          persistedState.devices.firstWhere((d) => d.id == 'balcony-bulb-1');
      expect(persistedDevice.isOn, isTrue);
      expect(persistedDevice.brightness, 85);
      expect(persistedDevice.roomId, 'balcony-room');
    });

    test(
        'Scenario 2: Sensor threshold automation -> sensor change -> rule executes -> activity event recorded',
        () async {
      // 1. Configure an automation rule with sensorThreshold trigger on custom sensor
      const tempRule = AutomationRule(
        id: 'sc2-temp-rule',
        name: 'Overheat AC Activation',
        isEnabled: true,
        triggerType: TriggerType.sensorThreshold,
        sensorDeviceId: 'device-sensor-custom',
        sensorProperty: 'temperature',
        operator: ComparisonOperator.greaterThan,
        thresholdValue: 28.0,
        actions: [
          DeviceAction(
            deviceId: 'device-ac-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
          DeviceAction(
            deviceId: 'device-ac-1',
            commandType: DeviceCommandType.setTargetTemperature,
            value: 20.0,
          ),
        ],
      );
      automationNotifier.addRule(tempRule);

      // Verify initial AC state
      final initialAc =
          repository.devices.firstWhere((d) => d.id == 'device-ac-1');
      expect(initialAc.targetTemperature, isNot(20.0));

      // 2. Sensor reading below threshold -> no execution
      final coldExecCount = await automationNotifier.evaluateSensorRules(
        sensorDeviceId: 'device-sensor-custom',
        property: 'temperature',
        value: 26.5,
        repo: repository,
        onActivityRecorded: activityNotifier.addEvent,
      );
      expect(coldExecCount, 0);

      // 3. Sensor reading exceeds threshold (29.2 > 28.0)
      final hotExecCount = await automationNotifier.evaluateSensorRules(
        sensorDeviceId: 'device-sensor-custom',
        property: 'temperature',
        value: 29.2,
        repo: repository,
        onActivityRecorded: activityNotifier.addEvent,
      );
      expect(hotExecCount, 1);

      // 4. Rule executed: AC power turned on and target temp set to 20.0
      final updatedAc =
          repository.devices.firstWhere((d) => d.id == 'device-ac-1');
      expect(updatedAc.isOn, isTrue);
      expect(updatedAc.targetTemperature, 20.0);

      // 5. Activity event recorded
      expect(
        activityNotifier.state.any((e) =>
            e.source == 'automation' &&
            e.title.contains('Overheat AC Activation')),
        isTrue,
      );

      // 6. Rule lastExecutedAt timestamp updated
      final updatedRule =
          automationNotifier.state.firstWhere((r) => r.id == 'sc2-temp-rule');
      expect(updatedRule.lastExecutedAt, isNotNull);
    });

    test(
        'Scenario 3: Force device offline -> command fails safely -> reconnect -> control works',
        () async {
      const targetId = 'device-socket-1';
      final socket = repository.devices.firstWhere((d) => d.id == targetId);
      expect(socket.connection, DeviceConnection.online);
      expect(socket.isOn, isTrue);

      // 1. Force device offline
      repository.toggleDeviceConnection(targetId);
      expect(
        repository.devices.firstWhere((d) => d.id == targetId).connection,
        DeviceConnection.offline,
      );

      // 2. Send command to offline device
      final failedCmd = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'sc3-cmd-1',
          deviceId: targetId,
          type: DeviceCommandType.setPower,
          value: false,
        ),
      );

      // 3. Command fails safely
      expect(failedCmd.status, CommandStatus.failed);
      expect(failedCmd.errorMessage, 'Device offline');
      // State is untouched
      expect(
        repository.devices.firstWhere((d) => d.id == targetId).isOn,
        isTrue,
      );

      // 4. Reconnect device
      repository.toggleDeviceConnection(targetId);
      expect(
        repository.devices.firstWhere((d) => d.id == targetId).connection,
        DeviceConnection.online,
      );

      // 5. Retry command
      final successCmd = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'sc3-cmd-2',
          deviceId: targetId,
          type: DeviceCommandType.setPower,
          value: false,
        ),
      );

      // 6. Control works normally
      expect(successCmd.status, CommandStatus.confirmed);
      expect(
        repository.devices.firstWhere((d) => d.id == targetId).isOn,
        isFalse,
      );
    });

    test(
        'Scenario 4: Scheduled routine -> advance virtual clock -> automation executes once',
        () async {
      // 1. Routine scheduled for weekdays at 06:30
      const morningRule = AutomationRule(
        id: 'sc4-morning-rule',
        name: 'Curtain Opener Schedule',
        isEnabled: true,
        triggerType: TriggerType.schedule,
        timeOfDay: '06:30',
        daysOfWeek: [DateTime.monday, DateTime.tuesday, DateTime.wednesday],
        actions: [
          DeviceAction(
            deviceId: 'device-curtain-1',
            commandType: DeviceCommandType.setPosition,
            value: 100,
          ),
        ],
      );
      automationNotifier.addRule(morningRule);

      // Ensure curtain is closed initially
      await repository.sendCommand(
        const DeviceCommand(
          requestId: 'prep-curtain',
          deviceId: 'device-curtain-1',
          type: DeviceCommandType.setPosition,
          value: 0,
        ),
      );
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        0,
      );

      // Monday: 2026-10-19 is a Monday
      final mondayBefore = DateTime(2026, 10, 19, 6, 29);
      final executedBefore = await automationNotifier.evaluateScheduleRules(
        currentTime: mondayBefore,
        repo: repository,
        onActivityRecorded: activityNotifier.addEvent,
      );
      expect(executedBefore, 0);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        0,
      );

      // Advance virtual clock to Monday 06:30
      final mondayAt630 = DateTime(2026, 10, 19, 6, 30, 15);
      final executedAt630 = await automationNotifier.evaluateScheduleRules(
        currentTime: mondayAt630,
        repo: repository,
        onActivityRecorded: activityNotifier.addEvent,
      );
      expect(executedAt630, 1);
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-curtain-1')
            .position,
        100,
      );

      // Advance virtual clock to Monday 06:30:45 (same minute) -> must not re-run!
      final mondayAt630Later = DateTime(2026, 10, 19, 6, 30, 45);
      final executedSameMinute = await automationNotifier.evaluateScheduleRules(
        currentTime: mondayAt630Later,
        repo: repository,
        onActivityRecorded: activityNotifier.addEvent,
      );
      expect(executedSameMinute, 0);

      // Advance virtual clock to Sunday 06:30 (day not in schedule)
      final sundayAt630 = DateTime(2026, 10, 25, 6, 30);
      final executedSunday = await automationNotifier.evaluateScheduleRules(
        currentTime: sundayAt630,
        repo: repository,
        onActivityRecorded: activityNotifier.addEvent,
      );
      expect(executedSunday, 0);
    });

    test('Scenario 5: Reset Demo Data -> restore default home and devices',
        () async {
      // 1. Mutate state: add extra room, custom device, custom event, etc.
      await roomsNotifier.addRoom(
        const Room(id: 'room-garage', name: 'Garage'),
      );
      repository.addDevice(
        const SmartDevice(
          id: 'temp-dev-1',
          name: 'Temporary Sensor',
          roomId: 'room-garage',
          type: DeviceType.sensor,
          isOn: true,
        ),
      );
      activityNotifier.addEvent(
        ActivityEvent(
          id: 'temp-evt',
          title: 'Custom Event',
          description: 'Testing',
          timestamp: DateTime.now(),
        ),
      );
      notificationsNotifier.addNotification(
        InAppNotification(
          id: 'temp-notif',
          title: 'Custom Notif',
          body: 'Testing',
          timestamp: DateTime.now(),
        ),
      );

      expect(roomsNotifier.state.length, greaterThan(4));
      expect(repository.devices.length, 8);
      expect(
        repository.devices.any((d) => d.id == 'temp-dev-1'),
        isTrue,
      );

      // 2. Perform Reset Demo Data
      final demoState = await persistence.resetDemoData();
      repository.resetToDemo();
      await roomsNotifier.setRooms(demoState.rooms);
      automationNotifier.setRules(demoState.automations);
      activityNotifier.setEvents(demoState.activityEvents);
      notificationsNotifier.setNotifications(demoState.notifications);

      // 3. Verify restored default home state
      expect(demoState.schemaVersion, 2);

      // 7 devices across 3+ rooms
      expect(repository.devices.length, 7);
      expect(
        repository.devices.any((d) => d.id == 'temp-dev-1'),
        isFalse,
      );
      final types = repository.devices.map((d) => d.type).toSet();
      expect(types, contains(DeviceType.light));
      expect(types, contains(DeviceType.fan));
      expect(types, contains(DeviceType.ac));
      expect(types, contains(DeviceType.socket));
      expect(types, contains(DeviceType.curtain));
      expect(types, contains(DeviceType.lock));
      expect(types, contains(DeviceType.sensor));

      // 4 default rooms restored
      expect(roomsNotifier.state.length, 4);
      expect(roomsNotifier.state.any((r) => r.id == 'room-garage'), isFalse);

      // Default scenes and automations intact
      expect(demoState.scenes.length, greaterThanOrEqualTo(3));
      expect(demoState.automations.length, greaterThanOrEqualTo(3));

      // Reloading persistence verifies persistent storage matches demo state
      final reloadedState = await persistence.loadHomeState();
      expect(reloadedState.devices.length, 7);
      expect(reloadedState.rooms.length, 4);
    });
  });
}
