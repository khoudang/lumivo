import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/automation_rule.dart';

class AutomationHistoryNotifier
    extends StateNotifier<List<AutomationExecutionRecord>> {
  AutomationHistoryNotifier([List<AutomationExecutionRecord>? initial])
      : super(initial ?? _defaultRecords);

  static final List<AutomationExecutionRecord> _defaultRecords = [
    AutomationExecutionRecord(
      id: 'exec-1',
      ruleId: 'rule-night-lock',
      ruleName: 'Night Lock Guard',
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      status: AutomationExecutionStatus.executed,
      reason: 'Scheduled trigger matched (23:00). Lock secured.',
      dispatchedCommandIds: ['cmd-lock-1'],
    ),
    AutomationExecutionRecord(
      id: 'exec-2',
      ruleId: 'rule-temp-trigger',
      ruleName: 'Auto Cool Living Room',
      timestamp: DateTime.now().subtract(const Duration(minutes: 32)),
      status: AutomationExecutionStatus.skipped,
      reason:
          'Skipped: trigger conditions not met (sensor temperature 24.5°C <= 26.0°C).',
    ),
    AutomationExecutionRecord(
      id: 'exec-3',
      ruleId: 'rule-morning-routine',
      ruleName: 'Morning Routine',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      status: AutomationExecutionStatus.loopPrevented,
      reason: 'Loop prevented: rule recursed too rapidly (5 dispatches in 2s).',
    ),
    AutomationExecutionRecord(
      id: 'exec-4',
      ruleId: 'rule-failed-sample',
      ruleName: 'Perimeter Alert',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      status: AutomationExecutionStatus.failed,
      reason: 'Device unreachable during command execution (timeout).',
    ),
  ];

  void addRecord(AutomationExecutionRecord record) {
    state = [record, ...state];
  }

  void clearHistory() {
    state = const [];
  }

  void reset() {
    state = List.of(_defaultRecords);
  }
}

final automationHistoryProvider = StateNotifierProvider<
    AutomationHistoryNotifier, List<AutomationExecutionRecord>>((ref) {
  return AutomationHistoryNotifier();
});
