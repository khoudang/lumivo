import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/automation_rule.dart';

/// State notifier managing a bounded list of automation execution records (up to 100 entries).
/// Provides automatic loop prevention, execution explanation tracking,
/// filtering, and per-home persistence isolation.
class AutomationHistoryNotifier
    extends StateNotifier<List<AutomationExecutionRecord>> {
  AutomationHistoryNotifier({
    List<AutomationExecutionRecord>? initialRecords,
    this.persistenceManager,
    this.currentHomeId = 'home-default',
  }) : super(
          (initialRecords ?? const [])
              .where((r) => r.homeId == currentHomeId)
              .take(maxCapacity)
              .toList(),
        );

  final HomePersistenceManager? persistenceManager;
  final String currentHomeId;

  static const int maxCapacity = 100;

  /// Tracks execution timestamps to detect rapid recursion/loops
  final Map<String, List<DateTime>> _executionTimestamps = {};

  /// Checks if executing [ruleId] right now would violate loop protection thresholds
  /// (more than 3 executions within 5 seconds).
  bool isLoopDetected(String ruleId) {
    final now = DateTime.now();
    final times = _executionTimestamps[ruleId] ?? [];
    final recent = times
        .where((t) => now.difference(t) <= const Duration(seconds: 5))
        .toList();
    _executionTimestamps[ruleId] = recent;
    return recent.length >= 3;
  }

  void recordExecution(AutomationExecutionRecord record) {
    final next = [
      record,
      ...state.where((r) => r.id != record.id),
    ];
    state = next.take(maxCapacity).toList();
    _persist();
  }

  /// Evaluates and records rule execution attempt, applying loop protection if necessary.
  /// Returns whether the rule was permitted to execute.
  bool recordRuleExecution({
    required AutomationRule rule,
    required List<String> dispatchedCommandIds,
    String? customReason,
    String? homeId,
  }) {
    final activeHomeId = homeId ?? currentHomeId;
    final now = DateTime.now();

    if (isLoopDetected(rule.id)) {
      final record = AutomationExecutionRecord(
        id: 'rec-loop-${rule.id}-${now.microsecondsSinceEpoch}',
        ruleId: rule.id,
        ruleName: rule.name,
        timestamp: now,
        status: AutomationExecutionStatus.loopPrevented,
        reason: 'Loop prevented: rule recursed too rapidly',
        dispatchedCommandIds: const [],
        homeId: activeHomeId,
      );
      recordExecution(record);
      return false; // loop prevented
    }

    final times = _executionTimestamps[rule.id] ?? [];
    times.add(now);
    _executionTimestamps[rule.id] = times;

    final record = AutomationExecutionRecord(
      id: 'rec-exec-${rule.id}-${now.microsecondsSinceEpoch}',
      ruleId: rule.id,
      ruleName: rule.name,
      timestamp: now,
      status: AutomationExecutionStatus.executed,
      reason: customReason ??
          'Executed ${rule.actions.length} action(s) via ${rule.triggerType.name}',
      dispatchedCommandIds: dispatchedCommandIds,
      homeId: activeHomeId,
    );
    recordExecution(record);
    return true;
  }

  void recordSkipped({
    required AutomationRule rule,
    String reason = 'Skipped: trigger conditions not met',
    String? homeId,
  }) {
    final activeHomeId = homeId ?? currentHomeId;
    final now = DateTime.now();
    final record = AutomationExecutionRecord(
      id: 'rec-skip-${rule.id}-${now.microsecondsSinceEpoch}',
      ruleId: rule.id,
      ruleName: rule.name,
      timestamp: now,
      status: AutomationExecutionStatus.skipped,
      reason: reason,
      dispatchedCommandIds: const [],
      homeId: activeHomeId,
    );
    recordExecution(record);
  }

  List<AutomationExecutionRecord> filterByRule(String ruleId) {
    return state.where((r) => r.ruleId == ruleId).toList();
  }

  List<AutomationExecutionRecord> filterByStatus(
      AutomationExecutionStatus status) {
    return state.where((r) => r.status == status).toList();
  }

  void clearHistory() {
    state = const [];
    _executionTimestamps.clear();
    _persist();
  }

  void _persist() {
    persistenceManager?.saveAutomationRecords(state, homeId: currentHomeId);
  }
}

/// Provider for automation execution history scoped to the current active home.
final automationExecutionHistoryProvider = StateNotifierProvider<
    AutomationHistoryNotifier, List<AutomationExecutionRecord>>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final currentHome = ref.watch(currentHomeProvider);
  final initial = persistence.getAutomationRecords(homeId: currentHome.id);

  return AutomationHistoryNotifier(
    initialRecords: initial,
    persistenceManager: persistence,
    currentHomeId: currentHome.id,
  );
});
