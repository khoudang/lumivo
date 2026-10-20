import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';

void main() {
  group('AutomationEngine Unit Tests', () {
    test('Schedule rule executes when virtual clock enters target minute',
        () async {
      final dispatchedActions = <DeviceAction>[];
      final events = <ActivityEvent>[];

      final rule = AutomationRule(
        id: 'rule-morning-light',
        name: 'Morning Lights On',
        isEnabled: true,
        triggerType: TriggerType.schedule,
        timeOfDay: '07:00',
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
        actions: const [
          DeviceAction(
            deviceId: 'light-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      final engine = AutomationEngine(
        initialRules: [rule],
        onDispatchAction: (action) async {
          dispatchedActions.add(action);
        },
      );
      engine.activityStream.listen(events.add);

      // Tuesday 06:59:50 - Should not trigger
      final timeBefore = DateTime(2026, 10, 20, 6, 59, 50);
      await engine.evaluate(virtualTime: timeBefore, devices: []);
      expect(dispatchedActions, isEmpty);
      expect(events, isEmpty);

      // Tuesday 07:00:00 - Target minute: Triggers!
      final timeTarget = DateTime(2026, 10, 20, 7, 0, 0);
      await engine.evaluate(virtualTime: timeTarget, devices: []);
      expect(dispatchedActions.length, 1);
      expect(dispatchedActions.first.deviceId, 'light-1');
      expect(dispatchedActions.first.value, true);

      expect(events.length, 1);
      expect(events.first.title, 'Automation: Morning Lights On');
      expect(events.first.source, 'automation');

      // Deduplication: evaluate again at 07:00:30 (same minute) - must NOT trigger again
      final timeSameMinute = DateTime(2026, 10, 20, 7, 0, 30);
      await engine.evaluate(virtualTime: timeSameMinute, devices: []);
      expect(dispatchedActions.length, 1,
          reason: 'Must not trigger duplicate actions in same minute');
      expect(events.length, 1);

      // Next minute 07:01:00 - Should not trigger
      final timeNextMinute = DateTime(2026, 10, 20, 7, 1, 0);
      await engine.evaluate(virtualTime: timeNextMinute, devices: []);
      expect(dispatchedActions.length, 1);

      engine.dispose();
    });

    test('Schedule rule does not fire on excluded days of week or if disabled',
        () async {
      var fired = false;
      final weekdayOnlyRule = AutomationRule(
        id: 'rule-weekday',
        name: 'Weekday Only',
        isEnabled: true,
        triggerType: TriggerType.schedule,
        timeOfDay: '08:00',
        // Monday through Friday only
        daysOfWeek: const [1, 2, 3, 4, 5],
        actions: const [
          DeviceAction(
            deviceId: 'fan-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      final engine = AutomationEngine(
        initialRules: [weekdayOnlyRule],
        onDispatchAction: (a) async => fired = true,
      );

      // 2026-10-25 is a Sunday (weekday == 7)
      final sunday = DateTime(2026, 10, 25, 8, 0, 0);
      expect(sunday.weekday, 7);

      await engine.evaluate(virtualTime: sunday, devices: []);
      expect(fired, isFalse);

      // Disabled rule test
      engine.updateRule(weekdayOnlyRule.copyWith(
        isEnabled: false,
        daysOfWeek: const [7],
      ));
      await engine.evaluate(virtualTime: sunday, devices: []);
      expect(fired, isFalse);

      engine.dispose();
    });

    test(
        'Sensor threshold rule triggers on greaterThan with hysteresis preventing rapid flapping',
        () async {
      final dispatched = <DeviceCommand>[];
      final events = <ActivityEvent>[];

      final rule = AutomationRule(
        id: 'rule-ac-cooling',
        name: 'Auto AC Cool Down',
        isEnabled: true,
        triggerType: TriggerType.sensorThreshold,
        sensorDeviceId: 'sensor-temp-1',
        sensorProperty: 'temperature',
        operator: ComparisonOperator.greaterThan,
        thresholdValue: 28.0,
        actions: const [
          DeviceAction(
            deviceId: 'ac-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      final engine = AutomationEngine(
        initialRules: [rule],
        hysteresis: 0.5,
        onSendCommand: (cmd) async {
          dispatched.add(cmd);
          return const CommandResult(
            requestId: 'test',
            status: CommandStatus.confirmed,
          );
        },
      );
      engine.activityStream.listen(events.add);

      var sensor = const SmartDevice(
        id: 'sensor-temp-1',
        name: 'Room Sensor',
        roomId: 'Living Room',
        type: DeviceType.sensor,
        isOn: true,
        currentTemperature: 27.5,
      );

      final time = DateTime(2026, 10, 20, 14, 0, 0);

      // 1. Initial temp 27.5 <= 28.0 -> Does not fire
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched, isEmpty);

      // 2. Temp rises to 28.2 (> 28.0) -> Fires!
      sensor = sensor.copyWith(currentTemperature: 28.2);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1);
      expect(dispatched.first.deviceId, 'ac-1');
      expect(dispatched.first.value, true);
      expect(events.length, 1);

      // 3. Flapping: Temp dips slightly to 27.8 (which is > 28.0 - 0.5 = 27.5) -> Still active, does not re-arm
      sensor = sensor.copyWith(currentTemperature: 27.8);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1,
          reason:
              'Hysteresis prevents resetting before reaching reset threshold');

      // 4. Temp bounces back up to 28.3 -> Should NOT trigger again because it never re-armed!
      sensor = sensor.copyWith(currentTemperature: 28.3);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1,
          reason:
              'Must not re-fire without first falling below hysteresis reset bound');

      // 5. Temp drops below 27.5 (28.0 - 0.5 = 27.5) -> Re-arms!
      sensor = sensor.copyWith(currentTemperature: 27.4);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1);

      // 6. Temp rises again above 28.0 to 28.5 -> Fires second time!
      sensor = sensor.copyWith(currentTemperature: 28.5);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 2);
      expect(events.length, 2);

      engine.dispose();
    });

    test('Sensor threshold rule triggers on lessThan with hysteresis',
        () async {
      final dispatched = <DeviceCommand>[];
      final rule = AutomationRule(
        id: 'rule-heater',
        name: 'Cold Weather Alert',
        isEnabled: true,
        triggerType: TriggerType.sensorThreshold,
        sensorDeviceId: 'sensor-temp-1',
        sensorProperty: 'temperature',
        operator: ComparisonOperator.lessThan,
        thresholdValue: 20.0,
        actions: const [
          DeviceAction(
            deviceId: 'socket-heater',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      final engine = AutomationEngine(
        initialRules: [rule],
        hysteresis: 0.5,
        onSendCommand: (cmd) async {
          dispatched.add(cmd);
          return const CommandResult(
            requestId: 'test',
            status: CommandStatus.confirmed,
          );
        },
      );

      var sensor = const SmartDevice(
        id: 'sensor-temp-1',
        name: 'Sensor',
        roomId: 'Living Room',
        type: DeviceType.sensor,
        isOn: true,
        currentTemperature: 22.0,
      );

      final time = DateTime(2026, 10, 20, 22, 0, 0);

      // 1. Temp is 22.0 -> Not less than 20.0
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched, isEmpty);

      // 2. Temp drops to 19.8 (< 20.0) -> Fires!
      sensor = sensor.copyWith(currentTemperature: 19.8);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1);

      // 3. Temp rises slightly to 20.2 (< 20.0 + 0.5 = 20.5) -> Still active
      sensor = sensor.copyWith(currentTemperature: 20.2);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1);

      // 4. Temp drops back to 19.5 -> Should NOT fire again
      sensor = sensor.copyWith(currentTemperature: 19.5);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1);

      // 5. Temp warms up to 20.6 (> 20.5) -> Re-armed!
      sensor = sensor.copyWith(currentTemperature: 20.6);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 1);

      // 6. Temp drops to 19.0 -> Fires second time!
      sensor = sensor.copyWith(currentTemperature: 19.0);
      await engine.evaluate(virtualTime: time, devices: [sensor]);
      expect(dispatched.length, 2);

      engine.dispose();
    });

    test('Dispatches commands through MockDeviceRepository', () async {
      final repo = MockDeviceRepository();
      final rule = AutomationRule(
        id: 'rule-repo',
        name: 'Turn On Bedside Light',
        isEnabled: true,
        triggerType: TriggerType.schedule,
        timeOfDay: '19:00',
        actions: const [
          DeviceAction(
            deviceId: 'light-2',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      final engine = AutomationEngine(
        initialRules: [rule],
        repository: repo,
      );

      // Initially light-2 is Off
      expect(repo.devices.firstWhere((d) => d.id == 'light-2').isOn, isFalse);

      await engine.evaluate(
        virtualTime: DateTime(2026, 10, 20, 19, 0, 0),
        devices: repo.devices,
      );

      // Light-2 should now be turned On in repository
      expect(repo.devices.firstWhere((d) => d.id == 'light-2').isOn, isTrue);

      engine.dispose();
      await repo.dispose();
    });
  });
}
