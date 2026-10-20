import 'dart:async';
import '../../core/models/activity_event.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/device_command.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';

/// Engine responsible for evaluating smart home automation rules against
/// virtual clock time and sensor device states.
///
/// Features:
/// - Evaluates list of [AutomationRule]s.
/// - Schedule triggers: fires once when virtual clock enters the scheduled time window
///   with deduplication tracking so it does not fire repeatedly in the same minute.
/// - Sensor threshold triggers: evaluates operator (`greaterThan`, `lessThan`, `equals`)
///   with hysteresis to prevent rapid flapping.
/// - Dispatches commands through callback or repository.
/// - Emits [ActivityEvent] for each executed automation rule.
class AutomationEngine {
  AutomationEngine({
    List<AutomationRule>? initialRules,
    this.repository,
    this.onDispatchAction,
    this.onSendCommand,
    this.hysteresis = 0.5,
  }) {
    if (initialRules != null) {
      _rules.addAll(initialRules);
    }
  }

  final DeviceRepository? repository;
  final Future<void> Function(DeviceAction action)? onDispatchAction;
  final Future<CommandResult> Function(DeviceCommand command)? onSendCommand;

  /// Default hysteresis delta to prevent flapping around sensor thresholds.
  final double hysteresis;

  final List<AutomationRule> _rules = [];
  final List<ActivityEvent> _activityHistory = [];
  final StreamController<ActivityEvent> _activityController =
      StreamController<ActivityEvent>.broadcast(sync: true);
  final StreamController<DeviceCommand> _commandController =
      StreamController<DeviceCommand>.broadcast(sync: true);

  /// Minute deduplication key: `ruleId -> "yyyy-MM-dd HH:mm"`
  final Map<String, String> _lastExecutedScheduleMinute = {};

  /// Sensor threshold active state: `ruleId -> bool`
  final Map<String, bool> _sensorActiveStates = {};

  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<ActivityEvent> get activityHistory =>
      List.unmodifiable(_activityHistory);
  Stream<ActivityEvent> get activityStream => _activityController.stream;
  Stream<DeviceCommand> get commandStream => _commandController.stream;

  void addRule(AutomationRule rule) {
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
  }

  void removeRule(String ruleId) {
    _rules.removeWhere((r) => r.id == ruleId);
    _lastExecutedScheduleMinute.remove(ruleId);
    _sensorActiveStates.remove(ruleId);
  }

  void updateRule(AutomationRule rule) {
    addRule(rule);
  }

  void setRules(List<AutomationRule> rules) {
    _rules.clear();
    _rules.addAll(rules);
  }

  /// Resets execution caches and hysteresis states.
  void reset() {
    _lastExecutedScheduleMinute.clear();
    _sensorActiveStates.clear();
  }

  /// Evaluates all active automation rules against current virtual time and device states.
  Future<void> evaluate({
    required DateTime virtualTime,
    required Iterable<SmartDevice> devices,
  }) async {
    final deviceMap = {for (final d in devices) d.id: d};

    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (!rule.isEnabled) continue;

      switch (rule.triggerType) {
        case TriggerType.schedule:
          await _evaluateScheduleRule(rule, virtualTime, i);
          break;
        case TriggerType.sensorThreshold:
          await _evaluateSensorThresholdRule(rule, virtualTime, deviceMap, i);
          break;
        case TriggerType.deviceState:
          // Optional/extensible: device state triggers
          break;
      }
    }
  }

  Future<void> _evaluateScheduleRule(
    AutomationRule rule,
    DateTime virtualTime,
    int ruleIndex,
  ) async {
    // Check days of week (1 = Monday, 7 = Sunday)
    if (!rule.daysOfWeek.contains(virtualTime.weekday)) return;

    if (rule.timeOfDay == null || !rule.timeOfDay!.contains(':')) return;
    final parts = rule.timeOfDay!.split(':');
    final targetHour = int.tryParse(parts[0].trim());
    final targetMinute = int.tryParse(parts[1].trim());
    if (targetHour == null || targetMinute == null) return;

    if (virtualTime.hour == targetHour && virtualTime.minute == targetMinute) {
      final minuteKey =
          '${virtualTime.year}-${virtualTime.month.toString().padLeft(2, '0')}-${virtualTime.day.toString().padLeft(2, '0')} '
          '${targetHour.toString().padLeft(2, '0')}:${targetMinute.toString().padLeft(2, '0')}';

      // Deduplication: fire only once per scheduled minute
      if (_lastExecutedScheduleMinute[rule.id] == minuteKey) {
        return;
      }

      _lastExecutedScheduleMinute[rule.id] = minuteKey;
      await _executeRule(rule, virtualTime, ruleIndex);
    }
  }

  Future<void> _evaluateSensorThresholdRule(
    AutomationRule rule,
    DateTime virtualTime,
    Map<String, SmartDevice> deviceMap,
    int ruleIndex,
  ) async {
    if (rule.sensorDeviceId == null) return;
    final sensor = deviceMap[rule.sensorDeviceId];
    if (sensor == null) return;

    final double value = (rule.sensorProperty.toLowerCase() == 'humidity')
        ? sensor.currentHumidity
        : sensor.currentTemperature;

    final bool isActive = _sensorActiveStates[rule.id] ?? false;

    switch (rule.operator) {
      case ComparisonOperator.greaterThan:
        if (!isActive) {
          if (value > rule.thresholdValue) {
            _sensorActiveStates[rule.id] = true;
            await _executeRule(rule, virtualTime, ruleIndex);
          }
        } else {
          // Reset/re-arm when value falls below thresholdValue - hysteresis
          if (value <= (rule.thresholdValue - hysteresis)) {
            _sensorActiveStates[rule.id] = false;
          }
        }
        break;

      case ComparisonOperator.lessThan:
        if (!isActive) {
          if (value < rule.thresholdValue) {
            _sensorActiveStates[rule.id] = true;
            await _executeRule(rule, virtualTime, ruleIndex);
          }
        } else {
          // Reset/re-arm when value rises above thresholdValue + hysteresis
          if (value >= (rule.thresholdValue + hysteresis)) {
            _sensorActiveStates[rule.id] = false;
          }
        }
        break;

      case ComparisonOperator.equals:
        const epsilon = 0.05;
        if (!isActive) {
          if ((value - rule.thresholdValue).abs() <= epsilon) {
            _sensorActiveStates[rule.id] = true;
            await _executeRule(rule, virtualTime, ruleIndex);
          }
        } else {
          // Reset when value deviates beyond hysteresis
          if ((value - rule.thresholdValue).abs() > hysteresis) {
            _sensorActiveStates[rule.id] = false;
          }
        }
        break;
    }
  }

  Future<void> _executeRule(
    AutomationRule rule,
    DateTime timestamp,
    int ruleIndex,
  ) async {
    // Update rule lastExecutedAt
    final updatedRule = rule.copyWith(lastExecutedAt: timestamp);
    if (ruleIndex >= 0 && ruleIndex < _rules.length) {
      _rules[ruleIndex] = updatedRule;
    }

    // Dispatch all actions
    for (var i = 0; i < rule.actions.length; i++) {
      final action = rule.actions[i];
      final command = DeviceCommand(
        requestId: 'auto-${rule.id}-${timestamp.millisecondsSinceEpoch}-$i',
        deviceId: action.deviceId,
        type: action.commandType,
        value: action.value,
      );

      if (!_commandController.isClosed) {
        _commandController.add(command);
      }

      if (onDispatchAction != null) {
        await onDispatchAction!(action);
      } else if (onSendCommand != null) {
        await onSendCommand!(command);
      } else if (repository != null) {
        await repository!.sendCommand(command);
      }
    }

    // Emit ActivityEvent
    final event = ActivityEvent(
      id: 'act-${rule.id}-${timestamp.millisecondsSinceEpoch}',
      title: 'Automation: ${rule.name}',
      description:
          'Executed ${rule.actions.length} action(s) via ${rule.triggerType.name}',
      timestamp: timestamp,
      deviceId: rule.sensorDeviceId ??
          (rule.actions.isNotEmpty ? rule.actions.first.deviceId : null),
      severity: ActivitySeverity.info,
      source: 'automation',
    );

    _activityHistory.add(event);
    if (!_activityController.isClosed) {
      _activityController.add(event);
    }
  }

  void dispose() {
    _activityController.close();
    _commandController.close();
  }
}
