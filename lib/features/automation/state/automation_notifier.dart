import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/repositories/device_repository.dart';
import '../../../services/storage/home_persistence_manager.dart';

class AutomationNotifier extends StateNotifier<List<AutomationRule>> {
  AutomationNotifier([
    List<AutomationRule>? initialRules,
    this._persistenceManager,
  ]) : super(
            initialRules ?? List.of(HomePersistenceManager.defaultAutomations));

  final HomePersistenceManager? _persistenceManager;

  void addRule(AutomationRule rule) {
    final index = state.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) rule else state[i],
      ];
    } else {
      state = [...state, rule];
    }
    _persist();
  }

  void deleteRule(String id) {
    state = state.where((r) => r.id != id).toList();
    _persist();
  }

  void toggleRule(String id) {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(isEnabled: !r.isEnabled) else r,
    ];
    _persist();
  }

  void disableRule(String id) {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(isEnabled: false) else r,
    ];
    _persist();
  }

  AutomationRule duplicateRule(String id) {
    final original = state.firstWhere(
      (r) => r.id == id,
      orElse: () => throw ArgumentError('Rule not found: $id'),
    );
    final duplicate = original.copyWith(
      id: '${original.id}-copy-${DateTime.now().millisecondsSinceEpoch}',
      name: '${original.name} (Copy)',
    );
    addRule(duplicate);
    return duplicate;
  }

  void updateRule(AutomationRule rule) {
    state = [
      for (final r in state)
        if (r.id == rule.id) rule else r,
    ];
    _persist();
  }

  void setRules(List<AutomationRule> rules) {
    state = List.of(rules);
    _persist();
  }

  void reset() {
    setRules(HomePersistenceManager.defaultAutomations);
  }

  Future<void> executeRule(
    AutomationRule rule,
    DeviceRepository repo, [
    void Function(ActivityEvent event)? onActivityRecorded,
  ]) async {
    for (final action in rule.actions) {
      await repo.sendCommand(
        DeviceCommand(
          requestId: 'rule-${rule.id}-${DateTime.now().microsecondsSinceEpoch}',
          deviceId: action.deviceId,
          type: action.commandType,
          value: action.value,
        ),
      );
    }

    final updated = rule.copyWith(lastExecutedAt: DateTime.now());
    updateRule(updated);

    onActivityRecorded?.call(
      ActivityEvent(
        id: 'evt-rule-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Rule Executed: ${rule.name}',
        description: 'Applied ${rule.actions.length} action(s)',
        timestamp: DateTime.now(),
        deviceId: rule.sensorDeviceId,
        severity: ActivitySeverity.info,
        source: 'automation',
      ),
    );
  }

  Future<int> evaluateSensorRules({
    required String sensorDeviceId,
    required String property,
    required double value,
    required DeviceRepository repo,
    void Function(ActivityEvent event)? onActivityRecorded,
  }) async {
    int executedCount = 0;
    for (final rule in state) {
      if (!rule.isEnabled ||
          rule.triggerType != TriggerType.sensorThreshold ||
          rule.sensorDeviceId != sensorDeviceId ||
          rule.sensorProperty != property) {
        continue;
      }

      bool conditionMet = false;
      switch (rule.operator) {
        case ComparisonOperator.greaterThan:
          conditionMet = value > rule.thresholdValue;
          break;
        case ComparisonOperator.lessThan:
          conditionMet = value < rule.thresholdValue;
          break;
        case ComparisonOperator.equals:
          conditionMet = value == rule.thresholdValue;
          break;
      }

      if (conditionMet) {
        for (final action in rule.actions) {
          await repo.sendCommand(
            DeviceCommand(
              requestId:
                  'sensor-rule-${rule.id}-${DateTime.now().microsecondsSinceEpoch}',
              deviceId: action.deviceId,
              type: action.commandType,
              value: action.value,
            ),
          );
        }

        final updated = rule.copyWith(lastExecutedAt: DateTime.now());
        updateRule(updated);
        executedCount++;

        onActivityRecorded?.call(
          ActivityEvent(
            id: 'evt-sensor-${DateTime.now().microsecondsSinceEpoch}',
            title: 'Automation: ${rule.name}',
            description:
                'Sensor $property reading ($value) met threshold condition (${rule.thresholdValue})',
            timestamp: DateTime.now(),
            deviceId: sensorDeviceId,
            severity: ActivitySeverity.info,
            source: 'automation',
          ),
        );
      }
    }
    return executedCount;
  }

  Future<int> evaluateScheduleRules({
    required DateTime currentTime,
    required DeviceRepository repo,
    void Function(ActivityEvent event)? onActivityRecorded,
  }) async {
    int executedCount = 0;
    for (final rule in state) {
      if (!rule.isEnabled ||
          rule.triggerType != TriggerType.schedule ||
          rule.timeOfDay == null) {
        continue;
      }

      final parts = rule.timeOfDay!.split(':');
      if (parts.length != 2) continue;
      final targetHour = int.tryParse(parts[0]);
      final targetMinute = int.tryParse(parts[1]);
      if (targetHour == null || targetMinute == null) continue;

      final weekdayMatches = rule.daysOfWeek.contains(currentTime.weekday);
      final timeMatches =
          currentTime.hour == targetHour && currentTime.minute == targetMinute;

      final alreadyRanThisMinute = rule.lastExecutedAt != null &&
          rule.lastExecutedAt!.year == currentTime.year &&
          rule.lastExecutedAt!.month == currentTime.month &&
          rule.lastExecutedAt!.day == currentTime.day &&
          rule.lastExecutedAt!.hour == currentTime.hour &&
          rule.lastExecutedAt!.minute == currentTime.minute;

      if (weekdayMatches && timeMatches && !alreadyRanThisMinute) {
        for (final action in rule.actions) {
          await repo.sendCommand(
            DeviceCommand(
              requestId:
                  'sched-${rule.id}-${DateTime.now().microsecondsSinceEpoch}',
              deviceId: action.deviceId,
              type: action.commandType,
              value: action.value,
            ),
          );
        }

        final updated = rule.copyWith(lastExecutedAt: currentTime);
        updateRule(updated);
        executedCount++;

        onActivityRecorded?.call(
          ActivityEvent(
            id: 'evt-sched-${DateTime.now().microsecondsSinceEpoch}',
            title: 'Schedule: ${rule.name}',
            description: 'Routine executed for time ${rule.timeOfDay}',
            timestamp: currentTime,
            severity: ActivitySeverity.info,
            source: 'automation',
          ),
        );
      }
    }
    return executedCount;
  }

  void _persist() {
    _persistenceManager?.saveAutomations(state);
  }
}

final automationProvider =
    StateNotifierProvider<AutomationNotifier, List<AutomationRule>>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final initial = persistence.cachedState?.automations ??
      HomePersistenceManager.defaultAutomations;
  return AutomationNotifier(initial, persistence);
});
