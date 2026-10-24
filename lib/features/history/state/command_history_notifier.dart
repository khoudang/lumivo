import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/device_command.dart';
import '../../../core/repositories/device_repository.dart';

/// State notifier managing a bounded list of command execution records (up to 100 entries).
/// Provides authoritative execution, duplicate request deduplication, filtering,
/// and per-home persistence isolation.
class CommandHistoryNotifier extends StateNotifier<List<CommandRecord>> {
  CommandHistoryNotifier({
    List<CommandRecord>? initialRecords,
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

  bool hasExecuted(String requestId) {
    return state.any((record) => record.requestId == requestId);
  }

  CommandRecord? getRecord(String requestId) {
    try {
      return state.firstWhere((r) => r.requestId == requestId);
    } catch (_) {
      return null;
    }
  }

  void recordCommand(CommandRecord record) {
    final next = [
      record,
      ...state.where((r) => r.requestId != record.requestId),
    ];
    state = next.take(maxCapacity).toList();
    _persist();
  }

  /// Executes command through repository with deduplication and duration telemetry.
  /// If requestId has already been executed, returns cached result without re-executing.
  Future<CommandResult> executeCommand(
    DeviceCommand command,
    DeviceRepository repository, {
    String? homeId,
  }) async {
    final activeHomeId = homeId ?? currentHomeId;

    if (hasExecuted(command.requestId)) {
      final existing = getRecord(command.requestId)!;
      return CommandResult(
        requestId: existing.requestId,
        status: existing.status,
        errorMessage: existing.errorMessage,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = await repository.sendCommand(command);
      stopwatch.stop();

      final record = CommandRecord(
        requestId: command.requestId,
        deviceId: command.deviceId,
        type: command.type,
        value: command.value,
        status: result.status,
        timestamp: DateTime.now(),
        executionDuration: stopwatch.elapsed,
        errorMessage: result.errorMessage,
        homeId: activeHomeId,
      );

      recordCommand(record);
      return result;
    } catch (e) {
      stopwatch.stop();
      final record = CommandRecord(
        requestId: command.requestId,
        deviceId: command.deviceId,
        type: command.type,
        value: command.value,
        status: CommandStatus.failed,
        timestamp: DateTime.now(),
        executionDuration: stopwatch.elapsed,
        errorMessage: e.toString(),
        homeId: activeHomeId,
      );
      recordCommand(record);
      return CommandResult(
        requestId: command.requestId,
        status: CommandStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  List<CommandRecord> filterByStatus(CommandStatus status) {
    return state.where((r) => r.status == status).toList();
  }

  List<CommandRecord> filterByDevice(String deviceId) {
    return state.where((r) => r.deviceId == deviceId).toList();
  }

  List<CommandRecord> filter({CommandStatus? status, String? deviceId}) {
    return state.where((r) {
      if (status != null && r.status != status) return false;
      if (deviceId != null && r.deviceId != deviceId) return false;
      return true;
    }).toList();
  }

  void clearHistory() {
    state = const [];
    _persist();
  }

  void _persist() {
    persistenceManager?.saveCommandRecords(state, homeId: currentHomeId);
  }
}

/// Provider for command execution history scoped to the current home.
final commandHistoryProvider =
    StateNotifierProvider<CommandHistoryNotifier, List<CommandRecord>>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final currentHome = ref.watch(currentHomeProvider);
  final initial = persistence.getCommandRecords(homeId: currentHome.id);

  return CommandHistoryNotifier(
    initialRecords: initial,
    persistenceManager: persistence,
    currentHomeId: currentHome.id,
  );
});
