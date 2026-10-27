import 'dart:async';
import 'dart:math';

import '../../core/models/device_command.dart';
import '../../core/models/smart_device.dart';

extension SmartDeviceOnlineExtension on SmartDevice {
  bool get isOnline => connection == DeviceConnection.online;
}

typedef CommandExecutor = Future<CommandResult> Function(DeviceCommand command);

/// Authoritative command execution pipeline supporting:
/// - Lifecycle states: queued -> pending -> confirmed/failed/timedOut/cancelled
/// - Deduplication by requestId
/// - Configurable simulated latency
/// - Simulated packet loss and timeout with bounded exponential backoff retries
/// - Command cancellation
/// - Emits `Stream<CommandRecord>` and keeps a bounded execution log
class CommandPipeline {
  CommandPipeline({
    this.executor,
    this.minLatencyMs = 20,
    this.maxLatencyMs = 60,
    this.simulatedLatency,
    this.packetLossRate = 0.0,
    this.maxRetries = 2,
    this.initialBackoff = const Duration(milliseconds: 100),
    this.maxBackoff = const Duration(milliseconds: 1500),
    this.backoffMultiplier = 2.0,
    this.commandTimeout = const Duration(seconds: 3),
    this.maxHistoryEntries = 200,
    Random? random,
  }) : _random = random ?? Random();

  final CommandExecutor? executor;
  final int minLatencyMs;
  final int maxLatencyMs;
  final Duration? simulatedLatency;
  double packetLossRate;
  final int maxRetries;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final double backoffMultiplier;
  final Duration commandTimeout;
  final int maxHistoryEntries;

  final Random _random;
  final Map<String, Completer<CommandResult>> _inFlight = {};
  final Map<String, DeviceCommand> _inFlightCommands = {};
  final Map<String, CommandResult> _completedResults = {};
  final Set<String> _cancelledRequestIds = {};
  final List<CommandRecord> _commandHistory = [];
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  final StreamController<CommandRecord> _recordController =
      StreamController<CommandRecord>.broadcast(sync: true);

  Stream<CommandRecord> get commandStream => _recordController.stream;
  List<CommandRecord> get commandHistory => List.unmodifiable(_commandHistory);

  /// Computes bounded exponential backoff for a given retry attempt index (0-based).
  Duration computeBackoff(int attempt) {
    if (initialBackoff == Duration.zero) return Duration.zero;
    final ms = (initialBackoff.inMilliseconds * pow(backoffMultiplier, attempt))
        .round();
    return Duration(milliseconds: min(ms, maxBackoff.inMilliseconds));
  }

  /// Resolves the simulated latency duration.
  Duration _resolveLatency() {
    if (simulatedLatency != null) return simulatedLatency!;
    if (maxLatencyMs <= minLatencyMs) {
      return Duration(milliseconds: minLatencyMs);
    }
    final ms = minLatencyMs + _random.nextInt(maxLatencyMs - minLatencyMs + 1);
    return Duration(milliseconds: ms);
  }

  /// Cancels an in-flight command by [requestId].
  /// Returns `true` if cancelled while queued or pending, `false` otherwise.
  Future<bool> cancelCommand(String requestId) async {
    if (_inFlight.containsKey(requestId)) {
      _cancelledRequestIds.add(requestId);
      if (_cancelledRequestIds.length > maxHistoryEntries * 2) {
        _cancelledRequestIds.remove(_cancelledRequestIds.first);
      }
      final completer = _inFlight.remove(requestId)!;
      final command = _inFlightCommands.remove(requestId);

      final result = CommandResult(
        requestId: requestId,
        status: CommandStatus.cancelled,
        errorMessage: 'Command cancelled',
      );
      _completedResults[requestId] = result;
      if (_completedResults.length > maxHistoryEntries * 2) {
        _completedResults.remove(_completedResults.keys.first);
      }

      final record = CommandRecord(
        requestId: requestId,
        deviceId: command?.deviceId ?? '',
        type: command?.type ?? DeviceCommandType.setPower,
        value: command?.value ?? false,
        status: CommandStatus.cancelled,
        timestamp: DateTime.now(),
        errorMessage: 'Command cancelled',
      );
      _emitRecord(record);

      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return true;
    }
    return false;
  }

  /// Executes a command through the authoritative lifecycle pipeline with deduplication.
  Future<CommandResult> execute(
    DeviceCommand command, {
    CommandExecutor? onExecute,
    String homeId = 'home-default',
  }) async {
    if (_isDisposed) {
      return CommandResult(
        requestId: command.requestId,
        status: CommandStatus.cancelled,
        errorMessage: 'CommandPipeline is disposed',
      );
    }
    final reqId = command.requestId;

    // Deduplication 1: If command is already completed/confirmed, return existing result.
    if (_completedResults.containsKey(reqId)) {
      return _completedResults[reqId]!;
    }

    // Deduplication 2: If command is currently queued or pending, return existing future.
    if (_inFlight.containsKey(reqId)) {
      return _inFlight[reqId]!.future;
    }

    final completer = Completer<CommandResult>();
    _inFlight[reqId] = completer;
    _inFlightCommands[reqId] = command;

    final startTime = DateTime.now();

    // 1. Queued state
    _emitRecord(CommandRecord(
      requestId: reqId,
      deviceId: command.deviceId,
      type: command.type,
      value: command.value,
      status: CommandStatus.queued,
      timestamp: startTime,
      homeId: homeId,
    ));

    // Asynchronously progress the lifecycle
    _runExecution(
      command: command,
      completer: completer,
      onExecute: onExecute ?? executor,
      startTime: startTime,
      homeId: homeId,
    );

    return completer.future;
  }

  Future<void> _runExecution({
    required DeviceCommand command,
    required Completer<CommandResult> completer,
    required CommandExecutor? onExecute,
    required DateTime startTime,
    required String homeId,
  }) async {
    final reqId = command.requestId;

    if (_cancelledRequestIds.contains(reqId)) {
      _finishCommand(
        command: command,
        completer: completer,
        status: CommandStatus.cancelled,
        errorMessage: 'Command cancelled',
        startTime: startTime,
        homeId: homeId,
        retries: 0,
      );
      return;
    }

    // 2. Pending state
    _emitRecord(CommandRecord(
      requestId: reqId,
      deviceId: command.deviceId,
      type: command.type,
      value: command.value,
      status: CommandStatus.pending,
      timestamp: DateTime.now(),
      homeId: homeId,
    ));

    // Simulate initial latency
    final latency = _resolveLatency();
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    if (_cancelledRequestIds.contains(reqId)) {
      _finishCommand(
        command: command,
        completer: completer,
        status: CommandStatus.cancelled,
        errorMessage: 'Command cancelled',
        startTime: startTime,
        homeId: homeId,
        retries: 0,
      );
      return;
    }

    int attempt = 0;
    while (attempt <= maxRetries) {
      if (_cancelledRequestIds.contains(reqId)) {
        _finishCommand(
          command: command,
          completer: completer,
          status: CommandStatus.cancelled,
          errorMessage: 'Command cancelled',
          startTime: startTime,
          homeId: homeId,
          retries: attempt,
        );
        return;
      }

      // Check simulated packet loss
      final isDropped =
          packetLossRate > 0.0 && (_random.nextDouble() < packetLossRate);
      if (isDropped) {
        if (attempt < maxRetries) {
          attempt++;
          final backoff = computeBackoff(attempt - 1);
          if (backoff > Duration.zero) {
            await Future<void>.delayed(backoff);
          }
          continue;
        } else {
          _finishCommand(
            command: command,
            completer: completer,
            status: CommandStatus.timedOut,
            errorMessage:
                'Command timed out after $attempt retries due to packet loss',
            startTime: startTime,
            homeId: homeId,
            retries: attempt,
          );
          return;
        }
      }

      // Execute through hardware/mock executor
      try {
        Future<CommandResult> execFuture;
        if (onExecute != null) {
          execFuture = onExecute(command);
        } else {
          execFuture = Future.value(CommandResult(
            requestId: reqId,
            status: CommandStatus.confirmed,
          ));
        }

        final result = (commandTimeout > Duration.zero)
            ? await execFuture.timeout(commandTimeout)
            : await execFuture;

        if (result.status == CommandStatus.confirmed) {
          _finishCommand(
            command: command,
            completer: completer,
            status: CommandStatus.confirmed,
            startTime: startTime,
            homeId: homeId,
            retries: attempt,
          );
          return;
        }

        // Terminal failures (e.g. offline device or invalid argument) fail immediately
        if (result.status == CommandStatus.failed) {
          _finishCommand(
            command: command,
            completer: completer,
            status: CommandStatus.failed,
            errorMessage: result.errorMessage,
            startTime: startTime,
            homeId: homeId,
            retries: attempt,
          );
          return;
        }

        // Timeout or retryable status
        if (attempt < maxRetries) {
          attempt++;
          final backoff = computeBackoff(attempt - 1);
          if (backoff > Duration.zero) {
            await Future<void>.delayed(backoff);
          }
          continue;
        } else {
          _finishCommand(
            command: command,
            completer: completer,
            status: result.status,
            errorMessage: result.errorMessage,
            startTime: startTime,
            homeId: homeId,
            retries: attempt,
          );
          return;
        }
      } on TimeoutException {
        if (attempt < maxRetries) {
          attempt++;
          final backoff = computeBackoff(attempt - 1);
          if (backoff > Duration.zero) {
            await Future<void>.delayed(backoff);
          }
          continue;
        } else {
          _finishCommand(
            command: command,
            completer: completer,
            status: CommandStatus.timedOut,
            errorMessage: 'Command timed out',
            startTime: startTime,
            homeId: homeId,
            retries: attempt,
          );
          return;
        }
      } catch (e) {
        if (attempt < maxRetries) {
          attempt++;
          final backoff = computeBackoff(attempt - 1);
          if (backoff > Duration.zero) {
            await Future<void>.delayed(backoff);
          }
          continue;
        } else {
          _finishCommand(
            command: command,
            completer: completer,
            status: CommandStatus.failed,
            errorMessage: e.toString(),
            startTime: startTime,
            homeId: homeId,
            retries: attempt,
          );
          return;
        }
      }
    }
  }

  void _finishCommand({
    required DeviceCommand command,
    required Completer<CommandResult> completer,
    required CommandStatus status,
    String? errorMessage,
    required DateTime startTime,
    required String homeId,
    required int retries,
  }) {
    final duration = DateTime.now().difference(startTime);
    final record = CommandRecord(
      requestId: command.requestId,
      deviceId: command.deviceId,
      type: command.type,
      value: command.value,
      status: status,
      timestamp: DateTime.now(),
      executionDuration: duration,
      errorMessage: errorMessage,
      retryCount: retries,
      homeId: homeId,
    );

    final result = CommandResult(
      requestId: command.requestId,
      status: status,
      errorMessage: errorMessage,
    );

    _completedResults[command.requestId] = result;
    if (_completedResults.length > maxHistoryEntries * 2) {
      _completedResults.remove(_completedResults.keys.first);
    }
    _inFlight.remove(command.requestId);
    _inFlightCommands.remove(command.requestId);
    _emitRecord(record);

    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  void _emitRecord(CommandRecord record) {
    _commandHistory.add(record);
    if (_commandHistory.length > maxHistoryEntries) {
      _commandHistory.removeAt(0);
    }
    if (!_recordController.isClosed) {
      _recordController.add(record);
    }
  }

  void clearHistory() {
    _commandHistory.clear();
    _completedResults.clear();
    _cancelledRequestIds.clear();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final entry in _inFlight.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(CommandResult(
          requestId: entry.key,
          status: CommandStatus.cancelled,
          errorMessage: 'Command cancelled: CommandPipeline was disposed',
        ));
      }
    }
    _inFlight.clear();
    _inFlightCommands.clear();
    _completedResults.clear();
    _cancelledRequestIds.clear();
    _commandHistory.clear();
    _recordController.close();
  }
}
