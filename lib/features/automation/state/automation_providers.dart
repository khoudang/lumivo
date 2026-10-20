import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';

const List<AutomationRule> defaultAutomationRules = [
  AutomationRule(
    id: 'rule-1',
    name: 'Morning Routine',
    isEnabled: true,
    triggerType: TriggerType.schedule,
    timeOfDay: '07:30',
    daysOfWeek: [1, 2, 3, 4, 5],
    actions: [
      DeviceAction(
        deviceId: 'light-1',
        commandType: DeviceCommandType.setPower,
        value: true,
      ),
    ],
  ),
  AutomationRule(
    id: 'rule-2',
    name: 'Auto Cool Living Room',
    isEnabled: true,
    triggerType: TriggerType.sensorThreshold,
    sensorDeviceId: 'sensor-1',
    sensorProperty: 'temperature',
    operator: ComparisonOperator.greaterThan,
    thresholdValue: 28.0,
    actions: [
      DeviceAction(
        deviceId: 'ac-1',
        commandType: DeviceCommandType.setPower,
        value: true,
      ),
    ],
  ),
  AutomationRule(
    id: 'rule-3',
    name: 'Night Lock & Dark',
    isEnabled: true,
    triggerType: TriggerType.schedule,
    timeOfDay: '23:00',
    daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    actions: [
      DeviceAction(
        deviceId: 'light-1',
        commandType: DeviceCommandType.setPower,
        value: false,
      ),
      DeviceAction(
        deviceId: 'lock-1',
        commandType: DeviceCommandType.setLock,
        value: true,
      ),
    ],
  ),
];

const List<Scene> defaultScenes = [
  Scene(
    id: 'scene-1',
    name: 'Good Morning',
    iconName: 'wb_sunny_rounded',
    actions: [
      DeviceAction(
        deviceId: 'light-1',
        commandType: DeviceCommandType.setPower,
        value: true,
      ),
      DeviceAction(
        deviceId: 'curtain-1',
        commandType: DeviceCommandType.setPosition,
        value: 100,
      ),
    ],
  ),
  Scene(
    id: 'scene-2',
    name: 'Away',
    iconName: 'logout_rounded',
    actions: [
      DeviceAction(
        deviceId: 'light-1',
        commandType: DeviceCommandType.setPower,
        value: false,
      ),
      DeviceAction(
        deviceId: 'fan-1',
        commandType: DeviceCommandType.setPower,
        value: false,
      ),
      DeviceAction(
        deviceId: 'lock-1',
        commandType: DeviceCommandType.setLock,
        value: true,
      ),
    ],
  ),
  Scene(
    id: 'scene-3',
    name: 'Night',
    iconName: 'bedtime_rounded',
    actions: [
      DeviceAction(
        deviceId: 'light-1',
        commandType: DeviceCommandType.setPower,
        value: false,
      ),
      DeviceAction(
        deviceId: 'lock-1',
        commandType: DeviceCommandType.setLock,
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
        deviceId: 'light-1',
        commandType: DeviceCommandType.setBrightness,
        value: 20,
      ),
      DeviceAction(
        deviceId: 'curtain-1',
        commandType: DeviceCommandType.setPosition,
        value: 0,
      ),
    ],
  ),
];

class AutomationRulesNotifier extends StateNotifier<List<AutomationRule>> {
  AutomationRulesNotifier([List<AutomationRule>? initial])
      : super(initial ?? defaultAutomationRules);

  void toggleRule(String id) {
    state = [
      for (final rule in state)
        if (rule.id == id) rule.copyWith(isEnabled: !rule.isEnabled) else rule,
    ];
  }

  void addRule(AutomationRule rule) {
    state = [...state, rule];
  }

  void deleteRule(String id) {
    state = state.where((rule) => rule.id != id).toList();
  }

  void reset() {
    state = defaultAutomationRules;
  }
}

final automationRulesProvider =
    StateNotifierProvider<AutomationRulesNotifier, List<AutomationRule>>((ref) {
  return AutomationRulesNotifier();
});

final scenesProvider = Provider<List<Scene>>((ref) {
  return defaultScenes;
});
