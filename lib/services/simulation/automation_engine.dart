import 'dart:async';

import '../../core/models/activity_event.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/device_command.dart';
import '../../core/models/smart_device.dart';
import '../../core/repositories/device_repository.dart';

/// Engine responsible for evaluating smart home automation rules against
/// virtual clock time and sensor device states with loop protection,
/// rule validation, duplicate detection, and execution explanation logging.
class AutomationEngine {
  AutomationEngine({
    List<AutomationRule>? initialRules,
    this.repository,
    this.onDispatchAction,
    this.onSendCommand,
    this.hysteresis = 0.5,
    int maxExecutionHistory = 100,
  }) : maxExecutionHistory = maxExecutionHistory > 100
            ? 100
            : (maxExecutionHistory <= 0 ? 100 : maxExecutionHistory) {
    if (initialRules != null) {
      for (final rule in initialRules) {
        addRule(rule, allowDuplicates: true);
      }
    }
  }

  final DeviceRepository? repository;
  final Future<void> Function(DeviceAction action)? onDispatchAction;
  final Future<CommandResult> Function(DeviceCommand command)? onSendCommand;

  /// Default hysteresis delta to prevent flapping around sensor thresholds.
  final double hysteresis;
  final int maxExecutionHistory;

  final List<AutomationRule> _rules = [];
  final List<ActivityEvent> _activityHistory = [];
  final List<AutomationExecutionRecord> _executionHistory = [];

  final StreamController<ActivityEvent> _activityController =
      StreamController<ActivityEvent>.broadcast(sync: true);
  final StreamController<DeviceCommand> _commandController =
      StreamController<DeviceCommand>.broadcast(sync: true);
  final StreamController<AutomationExecutionRecord> _executionController =
      StreamController<AutomationExecutionRecord>.broadcast(sync: true);

  /// Minute deduplication key: `ruleId -> "yyyy-MM-dd HH:mm"`
  final Map<String, String> _lastExecutedScheduleMinute = {};

  /// Sensor threshold active state: `ruleId -> bool`
  final Map<String, bool> _sensorActiveStates = {};

  /// Frequency tracking for loop prevention: `ruleId -> list of timestamps`
  final Map<String, List<DateTime>> _ruleTriggerTimestamps = {};

  /// Recursion depth tracking
  int _recursionDepth = 0;

  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<ActivityEvent> get activityHistory =>
      List.unmodifiable(_activityHistory);
  List<AutomationExecutionRecord> get executionHistory =>
      List.unmodifiable(_executionHistory);

  Stream<ActivityEvent> get activityStream => _activityController.stream;
  Stream<DeviceCommand> get commandStream => _commandController.stream;
  Stream<AutomationExecutionRecord> get executionRecordStream =>
      _executionController.stream;
  Stream<AutomationExecutionRecord> get executionStream =>
      _executionController.stream;

  // ==========================================
  // Rule Validation & Duplicate Detection
  // ==========================================

  /// Validates that a rule has a non-empty name, valid trigger, and non-empty actions.
  static bool validateRule(AutomationRule rule) {
    return getValidationError(rule) == null;
  }

  /// Returns validation error message or null if valid.
  static String? getValidationError(AutomationRule rule) {
    if (rule.name.trim().isEmpty) {
      return 'Rule name cannot be empty';
    }
    if (rule.actions.isEmpty) {
      return 'Rule must specify at least one action';
    }
    switch (rule.triggerType) {
      case TriggerType.schedule:
        if (rule.timeOfDay == null || !rule.timeOfDay!.contains(':')) {
          return 'Schedule rule must have a valid timeOfDay (HH:mm)';
        }
        if (rule.daysOfWeek.isEmpty) {
          return 'Schedule rule must have at least one active day of week';
        }
        break;
      case TriggerType.sensorThreshold:
        if (rule.sensorDeviceId == null ||
            rule.sensorDeviceId!.trim().isEmpty) {
          return 'Sensor threshold rule must specify a sensorDeviceId';
        }
        break;
      case TriggerType.deviceState:
        if (rule.sensorDeviceId == null ||
            rule.sensorDeviceId!.trim().isEmpty) {
          return 'Device state rule must specify a target deviceId';
        }
        break;
    }
    return null;
  }

  /// Detects whether an identical trigger + action set is already present in active rules.
  bool isDuplicateRule(AutomationRule rule) {
    return _rules.any((existing) {
      if (existing.id == rule.id) return false;
      if (existing.triggerType != rule.triggerType) return false;

      // Compare Trigger parameters
      if (rule.triggerType == TriggerType.schedule) {
        if (existing.timeOfDay != rule.timeOfDay) return false;
        final s1 = existing.daysOfWeek.toSet();
        final s2 = rule.daysOfWeek.toSet();
        if (s1.length != s2.length || !s1.containsAll(s2)) return false;
      } else if (rule.triggerType == TriggerType.sensorThreshold) {
        if (existing.sensorDeviceId != rule.sensorDeviceId ||
            existing.sensorProperty != rule.sensorProperty ||
            existing.operator != rule.operator ||
            existing.thresholdValue != rule.thresholdValue) {
          return false;
        }
      }

      // Compare Actions
      if (existing.actions.length != rule.actions.length) return false;
      for (var i = 0; i < existing.actions.length; i++) {
        final a1 = existing.actions[i];
        final a2 = rule.actions[i];
        if (a1.deviceId != a2.deviceId ||
            a1.commandType != a2.commandType ||
            a1.value != a2.value) {
          return false;
        }
      }
      return true;
    });
  }

  /// Adds a rule after validation and duplicate detection.
  /// Throws [ArgumentError] if the rule is invalid or an identical duplicate exists.
  bool addRule(AutomationRule rule, {bool allowDuplicates = false}) {
    final validationError = getValidationError(rule);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }
    if (!allowDuplicates && isDuplicateRule(rule)) {
      throw ArgumentError(
          'Duplicate automation rule: an identical trigger and action set already exists');
    }
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
    return true;
  }

  /// Safely attempts to add a rule, returning false if validation or duplicate check fails.
  bool tryAddRule(AutomationRule rule, {bool allowDuplicates = false}) {
    if (!validateRule(rule)) return false;
    if (!allowDuplicates && isDuplicateRule(rule)) return false;
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
    return true;
  }

  void removeRule(String ruleId) {
    _rules.removeWhere((r) => r.id == ruleId);
    _lastExecutedScheduleMinute.remove(ruleId);
    _sensorActiveStates.remove(ruleId);
    _ruleTriggerTimestamps.remove(ruleId);
  }

  void updateRule(AutomationRule rule) {
    addRule(rule, allowDuplicates: true);
  }

  void setRules(List<AutomationRule> rules) {
    _rules.clear();
    for (final rule in rules) {
      addRule(rule, allowDuplicates: true);
    }
  }

  /// Resets execution caches and hysteresis states.
  void reset() {
    _lastExecutedScheduleMinute.clear();
    _sensorActiveStates.clear();
    _ruleTriggerTimestamps.clear();
    _recursionDepth = 0;
  }

  void clearHistory() {
    _activityHistory.clear();
    _executionHistory.clear();
  }

  // ==========================================
  // Rule Evaluation Engine
  // ==========================================

  /// Evaluates all active automation rules against current virtual time and device states.
  Future<void> evaluate({
    required DateTime virtualTime,
    required Iterable<SmartDevice> devices,
  }) async {
    final deviceMap = {for (final d in devices) d.id: d};

    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (!rule.isEnabled) {
        _emitExecutionRecord(
          rule: rule,
          status: AutomationExecutionStatus.skipped,
          reason: 'Rule is disabled',
          timestamp: virtualTime,
        );
        continue;
      }

      switch (rule.triggerType) {
        case TriggerType.schedule:
          await _evaluateScheduleRule(rule, virtualTime, i);
          break;
        case TriggerType.sensorThreshold:
          await _evaluateSensorThresholdRule(rule, virtualTime, deviceMap, i);
          break;
        case TriggerType.deviceState:
          // Extensible device state triggers
          break;
      }
    }
  }

  Future<void> _evaluateScheduleRule(
    AutomationRule rule,
    DateTime virtualTime,
    int ruleIndex,
  ) async {
    // Check days of week
    if (!rule.daysOfWeek.contains(virtualTime.weekday)) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.skipped,
        reason: 'Excluded day of week (${virtualTime.weekday})',
        timestamp: virtualTime,
      );
      return;
    }

    if (rule.timeOfDay == null || !rule.timeOfDay!.contains(':')) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.skipped,
        reason: 'Invalid timeOfDay',
        timestamp: virtualTime,
      );
      return;
    }

    final parts = rule.timeOfDay!.split(':');
    final targetHour = int.tryParse(parts[0].trim());
    final targetMinute = int.tryParse(parts[1].trim());
    if (targetHour == null || targetMinute == null) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.skipped,
        reason: 'Malformed schedule time',
        timestamp: virtualTime,
      );
      return;
    }

    if (virtualTime.hour == targetHour && virtualTime.minute == targetMinute) {
      final minuteKey =
          '${virtualTime.year}-${virtualTime.month.toString().padLeft(2, '0')}-${virtualTime.day.toString().padLeft(2, '0')} '
          '${targetHour.toString().padLeft(2, '0')}:${targetMinute.toString().padLeft(2, '0')}';

      // Deduplication: fire only once per scheduled minute
      if (_lastExecutedScheduleMinute[rule.id] == minuteKey) {
        _emitExecutionRecord(
          rule: rule,
          status: AutomationExecutionStatus.skipped,
          reason: 'Already executed for schedule minute $minuteKey',
          timestamp: virtualTime,
        );
        return;
      }

      _lastExecutedScheduleMinute[rule.id] = minuteKey;
      await _executeRuleWithProtection(
        rule,
        virtualTime,
        ruleIndex,
        triggerExplanation: 'Triggered by schedule ${rule.timeOfDay}',
      );
    } else {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.skipped,
        reason:
            'Schedule time ${rule.timeOfDay} does not match current time ${virtualTime.hour.toString().padLeft(2, '0')}:${virtualTime.minute.toString().padLeft(2, '0')}',
        timestamp: virtualTime,
      );
    }
  }

  Future<void> _evaluateSensorThresholdRule(
    AutomationRule rule,
    DateTime virtualTime,
    Map<String, SmartDevice> deviceMap,
    int ruleIndex,
  ) async {
    if (rule.sensorDeviceId == null) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.skipped,
        reason: 'Sensor device not specified',
        timestamp: virtualTime,
      );
      return;
    }
    final sensor = deviceMap[rule.sensorDeviceId];
    if (sensor == null) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.skipped,
        reason: 'Sensor device "${rule.sensorDeviceId}" not found',
        timestamp: virtualTime,
      );
      return;
    }

    final bool isHumidity = rule.sensorProperty.toLowerCase() == 'humidity';
    final double value =
        isHumidity ? sensor.currentHumidity : sensor.currentTemperature;
    final unit = isHumidity ? '%' : '°C';
    final propName =
        rule.sensorProperty[0].toUpperCase() + rule.sensorProperty.substring(1);

    final bool isActive = _sensorActiveStates[rule.id] ?? false;

    switch (rule.operator) {
      case ComparisonOperator.greaterThan:
        if (!isActive) {
          if (value > rule.thresholdValue) {
            _sensorActiveStates[rule.id] = true;
            await _executeRuleWithProtection(
              rule,
              virtualTime,
              ruleIndex,
              triggerExplanation:
                  '$propName ${value.toStringAsFixed(1)}$unit > ${rule.thresholdValue.toStringAsFixed(1)}$unit',
            );
          } else {
            _emitExecutionRecord(
              rule: rule,
              status: AutomationExecutionStatus.skipped,
              reason:
                  'Condition not met: $propName ${value.toStringAsFixed(1)}$unit <= ${rule.thresholdValue.toStringAsFixed(1)}$unit',
              timestamp: virtualTime,
            );
          }
        } else {
          // Reset/re-arm when value falls below thresholdValue - hysteresis
          if (value <= (rule.thresholdValue - hysteresis)) {
            _sensorActiveStates[rule.id] = false;
          }
          _emitExecutionRecord(
            rule: rule,
            status: AutomationExecutionStatus.skipped,
            reason: 'Condition already active (hysteresis hold)',
            timestamp: virtualTime,
          );
        }
        break;

      case ComparisonOperator.lessThan:
        if (!isActive) {
          if (value < rule.thresholdValue) {
            _sensorActiveStates[rule.id] = true;
            await _executeRuleWithProtection(
              rule,
              virtualTime,
              ruleIndex,
              triggerExplanation:
                  '$propName ${value.toStringAsFixed(1)}$unit < ${rule.thresholdValue.toStringAsFixed(1)}$unit',
            );
          } else {
            _emitExecutionRecord(
              rule: rule,
              status: AutomationExecutionStatus.skipped,
              reason:
                  'Condition not met: $propName ${value.toStringAsFixed(1)}$unit >= ${rule.thresholdValue.toStringAsFixed(1)}$unit',
              timestamp: virtualTime,
            );
          }
        } else {
          // Reset/re-arm when value rises above thresholdValue + hysteresis
          if (value >= (rule.thresholdValue + hysteresis)) {
            _sensorActiveStates[rule.id] = false;
          }
          _emitExecutionRecord(
            rule: rule,
            status: AutomationExecutionStatus.skipped,
            reason: 'Condition already active (hysteresis hold)',
            timestamp: virtualTime,
          );
        }
        break;

      case ComparisonOperator.equals:
        const epsilon = 0.05;
        if (!isActive) {
          if ((value - rule.thresholdValue).abs() <= epsilon) {
            _sensorActiveStates[rule.id] = true;
            await _executeRuleWithProtection(
              rule,
              virtualTime,
              ruleIndex,
              triggerExplanation:
                  '$propName ${value.toStringAsFixed(1)}$unit == ${rule.thresholdValue.toStringAsFixed(1)}$unit',
            );
          } else {
            _emitExecutionRecord(
              rule: rule,
              status: AutomationExecutionStatus.skipped,
              reason:
                  'Condition not met: $propName ${value.toStringAsFixed(1)}$unit != ${rule.thresholdValue.toStringAsFixed(1)}$unit',
              timestamp: virtualTime,
            );
          }
        } else {
          if ((value - rule.thresholdValue).abs() > hysteresis) {
            _sensorActiveStates[rule.id] = false;
          }
          _emitExecutionRecord(
            rule: rule,
            status: AutomationExecutionStatus.skipped,
            reason: 'Condition already active (hysteresis hold)',
            timestamp: virtualTime,
          );
        }
        break;
    }
  }

  // ==========================================
  // Loop-Protected Execution
  // ==========================================

  Future<void> _executeRuleWithProtection(
    AutomationRule rule,
    DateTime timestamp,
    int ruleIndex, {
    required String triggerExplanation,
  }) async {
    // 1. Recursion depth check: recurses > 3 levels deep
    if (_recursionDepth >= 3) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.loopPrevented,
        reason:
            'Loop prevented: Recursion depth (${_recursionDepth + 1}) exceeded limit (3)',
        timestamp: timestamp,
      );
      return;
    }

    // 2. Frequency check: triggers > 5 times within 1 second
    final history = _ruleTriggerTimestamps.putIfAbsent(rule.id, () => []);
    final cutoff = timestamp.subtract(const Duration(seconds: 1));
    history.removeWhere((t) => t.isBefore(cutoff));

    if (history.length >= 5) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.loopPrevented,
        reason:
            'Loop prevented: Rule triggered more than 5 times within 1 second',
        timestamp: timestamp,
      );
      return;
    }

    history.add(timestamp);

    _recursionDepth++;
    try {
      await _executeRule(rule, timestamp, ruleIndex, triggerExplanation);
    } finally {
      _recursionDepth--;
    }
  }

  Future<void> _executeRule(
    AutomationRule rule,
    DateTime timestamp,
    int ruleIndex,
    String triggerExplanation,
  ) async {
    // Update rule lastExecutedAt
    final updatedRule = rule.copyWith(lastExecutedAt: timestamp);
    if (ruleIndex >= 0 && ruleIndex < _rules.length) {
      _rules[ruleIndex] = updatedRule;
    }

    final dispatchedCommandIds = <String>[];
    bool hasFailure = false;
    String? failureReason;

    // Dispatch all actions
    for (var i = 0; i < rule.actions.length; i++) {
      final action = rule.actions[i];
      final cmdId = 'auto-${rule.id}-${timestamp.millisecondsSinceEpoch}-$i';
      dispatchedCommandIds.add(cmdId);

      final command = DeviceCommand(
        requestId: cmdId,
        deviceId: action.deviceId,
        type: action.commandType,
        value: action.value,
      );

      if (!_commandController.isClosed) {
        _commandController.add(command);
      }

      CommandResult? result;
      try {
        if (onDispatchAction != null) {
          await onDispatchAction!(action);
        } else if (onSendCommand != null) {
          result = await onSendCommand!(command);
        } else if (repository != null) {
          result = await repository!.sendCommand(command);
        }
      } catch (e) {
        hasFailure = true;
        failureReason = 'Device ${action.deviceId} error: $e';
      }

      if (result != null && result.status == CommandStatus.failed) {
        hasFailure = true;
        final err = result.errorMessage ?? 'Command failed';
        if (err.toLowerCase().contains('offline')) {
          failureReason = 'Device ${action.deviceId} offline';
        } else {
          failureReason = 'Device ${action.deviceId}: $err';
        }
      }
    }

    if (hasFailure) {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.failed,
        reason: failureReason ?? 'Action execution failed',
        timestamp: timestamp,
        dispatchedCommandIds: dispatchedCommandIds,
      );
    } else {
      _emitExecutionRecord(
        rule: rule,
        status: AutomationExecutionStatus.executed,
        reason: triggerExplanation,
        timestamp: timestamp,
        dispatchedCommandIds: dispatchedCommandIds,
      );
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
      severity: hasFailure ? ActivitySeverity.alert : ActivitySeverity.info,
      source: 'automation',
    );

    _activityHistory.add(event);
    if (_activityHistory.length > maxExecutionHistory) {
      _activityHistory.removeAt(0);
    }
    if (!_activityController.isClosed) {
      _activityController.add(event);
    }
  }

  void _emitExecutionRecord({
    required AutomationRule rule,
    required AutomationExecutionStatus status,
    required String reason,
    required DateTime timestamp,
    List<String> dispatchedCommandIds = const [],
  }) {
    final record = AutomationExecutionRecord(
      id: 'exec-${rule.id}-${timestamp.microsecondsSinceEpoch}-${_executionHistory.length}',
      ruleId: rule.id,
      ruleName: rule.name,
      timestamp: timestamp,
      status: status,
      reason: reason,
      dispatchedCommandIds: dispatchedCommandIds,
      homeId: rule.homeId,
    );

    _executionHistory.add(record);
    if (_executionHistory.length > maxExecutionHistory) {
      _executionHistory.removeAt(0);
    }

    if (!_executionController.isClosed) {
      _executionController.add(record);
    }
  }

  void dispose() {
    _activityController.close();
    _commandController.close();
    _executionController.close();
  }
}
