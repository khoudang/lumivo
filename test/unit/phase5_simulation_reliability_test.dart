import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/device_health.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/command_pipeline.dart';
import 'package:lumivo/services/simulation/health_aggregator.dart';
import 'package:lumivo/services/simulation/simulation_engine.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';

void main() {
  group('Phase 5 Simulation & Reliability Test Suite', () {
    // =========================================================================
    // 1. Command Pipeline Lifecycle
    // =========================================================================
    group('Authoritative Command Pipeline Lifecycle', () {
      test('lifecycle: queued -> pending -> confirmed', () async {
        final records = <CommandRecord>[];
        final pipeline = CommandPipeline(simulatedLatency: Duration.zero);
        final sub = pipeline.commandStream.listen(records.add);

        const command = DeviceCommand(
          requestId: 'cmd-life-1',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        final result = await pipeline.execute(
          command,
          onExecute: (cmd) async => CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.confirmed,
          ),
        );

        expect(result.status, CommandStatus.confirmed);
        expect(result.errorMessage, isNull);

        // Allow microtasks to deliver stream events
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(records.map((r) => r.status).toList(), [
          CommandStatus.queued,
          CommandStatus.pending,
          CommandStatus.confirmed,
        ]);
        expect(pipeline.commandHistory.length, 3);
        expect(pipeline.commandHistory.last.status, CommandStatus.confirmed);

        await sub.cancel();
        pipeline.dispose();
      });

      test('lifecycle: queued -> pending -> failed on non-retryable error',
          () async {
        final records = <CommandRecord>[];
        final pipeline = CommandPipeline(simulatedLatency: Duration.zero);
        final sub = pipeline.commandStream.listen(records.add);

        const command = DeviceCommand(
          requestId: 'cmd-life-failed',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        final result = await pipeline.execute(
          command,
          onExecute: (cmd) async => CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Device is offline',
          ),
        );

        expect(result.status, CommandStatus.failed);
        expect(result.errorMessage, 'Device is offline');

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(records.map((r) => r.status).toList(), [
          CommandStatus.queued,
          CommandStatus.pending,
          CommandStatus.failed,
        ]);

        await sub.cancel();
        pipeline.dispose();
      });

      test('lifecycle: queued -> pending -> timedOut on timeout', () async {
        final records = <CommandRecord>[];
        final pipeline = CommandPipeline(
          simulatedLatency: Duration.zero,
          initialBackoff: Duration.zero,
          maxRetries: 1,
          commandTimeout: const Duration(milliseconds: 20),
        );
        final sub = pipeline.commandStream.listen(records.add);

        const command = DeviceCommand(
          requestId: 'cmd-life-timeout',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        final result = await pipeline.execute(
          command,
          onExecute: (cmd) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        expect(result.status, CommandStatus.timedOut);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(records.last.status, CommandStatus.timedOut);
        expect(records.last.retryCount, 1);

        await sub.cancel();
        pipeline.dispose();
      });

      test('lifecycle: queued -> pending -> cancelled via cancelCommand',
          () async {
        final records = <CommandRecord>[];
        final pipeline = CommandPipeline(
          simulatedLatency: const Duration(milliseconds: 50),
        );
        final sub = pipeline.commandStream.listen(records.add);

        const command = DeviceCommand(
          requestId: 'cmd-to-cancel',
          deviceId: 'fan-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        final future = pipeline.execute(command);

        // Cancel while in flight
        final cancelled = await pipeline.cancelCommand('cmd-to-cancel');
        expect(cancelled, isTrue);

        final result = await future;
        expect(result.status, CommandStatus.cancelled);
        expect(result.errorMessage, 'Command cancelled');

        // Cancelling already cancelled returns false
        final cancelAgain = await pipeline.cancelCommand('cmd-to-cancel');
        expect(cancelAgain, isFalse);

        await sub.cancel();
        pipeline.dispose();
      });
    });

    // =========================================================================
    // 2. Command Deduplication
    // =========================================================================
    group('Command Deduplication', () {
      test(
          'duplicate requestId returns existing in-flight and completed result',
          () async {
        int executorInvocations = 0;
        final pipeline = CommandPipeline(
          simulatedLatency: const Duration(milliseconds: 20),
        );

        const command = DeviceCommand(
          requestId: 'dedup-req-123',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        // Launch two concurrent executions with same requestId
        final f1 = pipeline.execute(
          command,
          onExecute: (cmd) async {
            executorInvocations++;
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        final f2 = pipeline.execute(
          command,
          onExecute: (cmd) async {
            executorInvocations++;
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        final r1 = await f1;
        final r2 = await f2;

        expect(r1.status, CommandStatus.confirmed);
        expect(r2.status, CommandStatus.confirmed);
        expect(executorInvocations, 1,
            reason: 'In-flight duplicate must not re-trigger executor');

        // Launch third execution after completion
        final r3 = await pipeline.execute(
          command,
          onExecute: (cmd) async {
            executorInvocations++;
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        expect(r3.status, CommandStatus.confirmed);
        expect(executorInvocations, 1,
            reason: 'Completed duplicate must return cached result');

        pipeline.dispose();
      });
    });

    // =========================================================================
    // 3. Authoritative Repository Integration & Offline Rejection
    // =========================================================================
    group('MockDeviceRepository Integration & Offline Rejection', () {
      test('offline device rejects command with CommandStatus.failed',
          () async {
        final repo = MockDeviceRepository(
          responseDelay: Duration.zero,
          offlineErrorMessage: 'Device is offline',
        );

        // Force light-1 offline
        repo.forceDeviceOffline('light-1');
        final device = repo.devices.firstWhere((d) => d.id == 'light-1');
        expect(device.isOnline, isFalse);
        expect(device.connection, DeviceConnection.offline);

        // Send command
        final res = await repo.sendCommand(
          const DeviceCommand(
            requestId: 'cmd-offline-test',
            deviceId: 'light-1',
            type: DeviceCommandType.setPower,
            value: true,
          ),
        );

        expect(res.status, CommandStatus.failed);
        expect(res.errorMessage, anyOf('Device is offline', 'Device offline'));

        // Reconnect device and retry
        repo.reconnectDevice('light-1');
        final reconnected = repo.devices.firstWhere((d) => d.id == 'light-1');
        expect(reconnected.isOnline, isTrue);

        final resOnline = await repo.sendCommand(
          const DeviceCommand(
            requestId: 'cmd-online-test',
            deviceId: 'light-1',
            type: DeviceCommandType.setPower,
            value: true,
          ),
        );

        expect(resOnline.status, CommandStatus.confirmed);
        expect(repo.devices.firstWhere((d) => d.id == 'light-1').isOn, isTrue);

        await repo.dispose();
      });
    });

    // =========================================================================
    // 4. Bounded Exponential Backoff Retry
    // =========================================================================
    group('Bounded Exponential Backoff Retry', () {
      test('computeBackoff calculates bounded exponential durations', () {
        final pipeline = CommandPipeline(
          initialBackoff: const Duration(milliseconds: 100),
          maxBackoff: const Duration(milliseconds: 1500),
          backoffMultiplier: 2.0,
        );

        expect(pipeline.computeBackoff(0), const Duration(milliseconds: 100));
        expect(pipeline.computeBackoff(1), const Duration(milliseconds: 200));
        expect(pipeline.computeBackoff(2), const Duration(milliseconds: 400));
        expect(pipeline.computeBackoff(3), const Duration(milliseconds: 800));
        expect(pipeline.computeBackoff(4), const Duration(milliseconds: 1500));
        expect(pipeline.computeBackoff(5), const Duration(milliseconds: 1500));
      });

      test('retries transient failures up to maxRetries then succeeds',
          () async {
        int attempts = 0;
        final pipeline = CommandPipeline(
          simulatedLatency: Duration.zero,
          initialBackoff: Duration.zero,
          maxRetries: 2,
        );

        const command = DeviceCommand(
          requestId: 'retry-success-test',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        final result = await pipeline.execute(
          command,
          onExecute: (cmd) async {
            attempts++;
            if (attempts <= 2) {
              return CommandResult(
                requestId: cmd.requestId,
                status: CommandStatus.timedOut,
                errorMessage: 'Transient network glitch',
              );
            }
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        expect(result.status, CommandStatus.confirmed);
        expect(attempts, 3); // Initial attempt (0) + 2 retries (1, 2)
        expect(pipeline.commandHistory.last.retryCount, 2);

        pipeline.dispose();
      });

      test('packet loss simulation forces retries and exhausts to timedOut',
          () async {
        final pipeline = CommandPipeline(
          simulatedLatency: Duration.zero,
          initialBackoff: Duration.zero,
          packetLossRate: 1.0, // 100% loss
          maxRetries: 2,
        );

        const command = DeviceCommand(
          requestId: 'packet-loss-exhaust',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        final result = await pipeline.execute(command);
        expect(result.status, CommandStatus.timedOut);
        expect(result.errorMessage, contains('packet loss'));
        expect(pipeline.commandHistory.last.retryCount, 2);

        pipeline.dispose();
      });
    });

    // =========================================================================
    // 5. Rule Validation & Duplicate Detection
    // =========================================================================
    group('Automation Rule Validation & Duplicate Detection', () {
      test('validateRule detects invalid name, actions, and triggers', () {
        // Empty name
        const ruleNoName = AutomationRule(
          id: 'rule-empty-name',
          name: '  ',
          triggerType: TriggerType.schedule,
          timeOfDay: '08:00',
          actions: [
            DeviceAction(
              deviceId: 'light-1',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );
        expect(AutomationEngine.validateRule(ruleNoName), isFalse);
        expect(AutomationEngine.getValidationError(ruleNoName),
            'Rule name cannot be empty');

        // Empty actions
        const ruleNoActions = AutomationRule(
          id: 'rule-empty-actions',
          name: 'Valid Name',
          triggerType: TriggerType.schedule,
          timeOfDay: '08:00',
          actions: [],
        );
        expect(AutomationEngine.validateRule(ruleNoActions), isFalse);
        expect(AutomationEngine.getValidationError(ruleNoActions),
            'Rule must specify at least one action');

        // Missing schedule timeOfDay
        const ruleBadSchedule = AutomationRule(
          id: 'rule-bad-sched',
          name: 'Bad Schedule',
          triggerType: TriggerType.schedule,
          timeOfDay: null,
          actions: [
            DeviceAction(
              deviceId: 'light-1',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );
        expect(AutomationEngine.validateRule(ruleBadSchedule), isFalse);

        // Missing sensorDeviceId
        const ruleNoSensor = AutomationRule(
          id: 'rule-no-sensor',
          name: 'No Sensor',
          triggerType: TriggerType.sensorThreshold,
          sensorDeviceId: null,
          actions: [
            DeviceAction(
              deviceId: 'socket-1',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );
        expect(AutomationEngine.validateRule(ruleNoSensor), isFalse);
      });

      test('duplicate rule detection catches identical trigger and action sets',
          () {
        final engine = AutomationEngine();

        const ruleOriginal = AutomationRule(
          id: 'rule-orig',
          name: 'Morning Routine',
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
        );

        engine.addRule(ruleOriginal);

        // Duplicate with different ID and name
        const ruleDuplicate = AutomationRule(
          id: 'rule-clone',
          name: 'Copied Morning Routine',
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
        );

        expect(engine.isDuplicateRule(ruleDuplicate), isTrue);
        expect(
          () => engine.addRule(ruleDuplicate),
          throwsA(isA<ArgumentError>()),
        );
        expect(engine.tryAddRule(ruleDuplicate), isFalse);

        // Allowed with allowDuplicates: true
        expect(engine.addRule(ruleDuplicate, allowDuplicates: true), isTrue);
        expect(engine.rules.length, 2);

        engine.dispose();
      });
    });

    // =========================================================================
    // 6. Infinite Automation Loop Prevention
    // =========================================================================
    group('Infinite Automation Loop Prevention', () {
      test(
          'event storm: rule triggering > 5 times within 1 second halts execution',
          () async {
        final records = <AutomationExecutionRecord>[];
        int actionCount = 0;

        const rapidRule = AutomationRule(
          id: 'rule-storm',
          name: 'Rapid Fire Rule',
          triggerType: TriggerType.sensorThreshold,
          sensorDeviceId: 'sensor-temp',
          sensorProperty: 'temperature',
          operator: ComparisonOperator.greaterThan,
          thresholdValue: 25.0,
          actions: [
            DeviceAction(
              deviceId: 'fan-1',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );

        final engine = AutomationEngine(
          initialRules: [rapidRule],
          hysteresis: 0.1,
          onDispatchAction: (a) async => actionCount++,
        );
        engine.executionRecordStream.listen(records.add);

        const hotSensor = SmartDevice(
          id: 'sensor-temp',
          name: 'Living Room Sensor',
          roomId: 'Living Room',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 28.0,
        );

        const coolSensor = SmartDevice(
          id: 'sensor-temp',
          name: 'Living Room Sensor',
          roomId: 'Living Room',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 24.0,
        );

        final baseTime = DateTime(2026, 10, 24, 12, 0, 0);

        // Flap 6 times within 500ms (< 1 second)
        for (int i = 0; i < 6; i++) {
          final t = baseTime.add(Duration(milliseconds: i * 80));
          // Reset hysteresis
          await engine.evaluate(virtualTime: t, devices: [coolSensor]);
          // Trigger condition
          await engine.evaluate(virtualTime: t, devices: [hotSensor]);
        }

        expect(actionCount, 5,
            reason: 'Rule must halt execution on 6th trigger');

        final loopRecords = records
            .where((r) => r.status == AutomationExecutionStatus.loopPrevented)
            .toList();

        expect(loopRecords.isNotEmpty, isTrue);
        expect(
          loopRecords.first.reason,
          contains(
              'Loop prevented: Rule triggered more than 5 times within 1 second'),
        );

        engine.dispose();
      });

      test('recursion limit: halts cascading loops recursing > 3 levels deep',
          () async {
        final records = <AutomationExecutionRecord>[];
        late final AutomationEngine engine;

        final rules = List.generate(
          5,
          (i) => AutomationRule(
            id: 'rule-cascade-$i',
            name: 'Cascade Level $i',
            triggerType: TriggerType.schedule,
            timeOfDay: '10:00',
            actions: [
              DeviceAction(
                deviceId: 'light-$i',
                commandType: DeviceCommandType.setPower,
                value: true,
              ),
            ],
          ),
        );

        int currentRuleIndex = 0;
        final testTime = DateTime(2026, 10, 24, 10, 0, 0);

        engine = AutomationEngine(
          initialRules: [rules[0]],
          onDispatchAction: (action) async {
            currentRuleIndex++;
            if (currentRuleIndex < rules.length) {
              engine.setRules([rules[currentRuleIndex]]);
              await engine.evaluate(virtualTime: testTime, devices: []);
            }
          },
        );
        engine.executionRecordStream.listen(records.add);

        await engine.evaluate(virtualTime: testTime, devices: []);

        final loopPrevented = records
            .where((r) => r.status == AutomationExecutionStatus.loopPrevented);
        expect(loopPrevented.isNotEmpty, isTrue);
        expect(loopPrevented.first.reason, contains('Recursion depth'));

        engine.dispose();
      });
    });

    // =========================================================================
    // 7. Execution Explanations
    // =========================================================================
    group('Automation Execution Explanation Logs', () {
      test(
          'logs explicit reasons for executed, skipped, and failed automations',
          () async {
        final records = <AutomationExecutionRecord>[];

        const schedRule = AutomationRule(
          id: 'rule-sched-exp',
          name: 'Morning Alert',
          triggerType: TriggerType.schedule,
          timeOfDay: '07:00',
          actions: [
            DeviceAction(
              deviceId: 'bulb-1',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );

        const tempRule = AutomationRule(
          id: 'rule-temp-exp',
          name: 'High Temp Alert',
          triggerType: TriggerType.sensorThreshold,
          sensorDeviceId: 'sensor-temp',
          sensorProperty: 'temperature',
          operator: ComparisonOperator.greaterThan,
          thresholdValue: 28.0,
          actions: [
            DeviceAction(
              deviceId: 'socket-offline',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );

        final engine = AutomationEngine(
          initialRules: [schedRule, tempRule],
          onSendCommand: (cmd) async {
            if (cmd.deviceId == 'socket-offline') {
              return CommandResult(
                requestId: cmd.requestId,
                status: CommandStatus.failed,
                errorMessage: 'Device offline',
              );
            }
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );
        engine.executionRecordStream.listen(records.add);

        // 1. Skipped: schedule does not match (06:50) and temp condition not met (24.0 <= 28.0)
        var sensor = const SmartDevice(
          id: 'sensor-temp',
          name: 'Temp Sensor',
          roomId: 'Living Room',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 24.0,
        );

        await engine.evaluate(
          virtualTime: DateTime(2026, 10, 24, 6, 50),
          devices: [sensor],
        );

        final skippedSched = records.firstWhere((r) =>
            r.ruleId == 'rule-sched-exp' &&
            r.status == AutomationExecutionStatus.skipped);
        expect(skippedSched.reason,
            contains('Schedule time 07:00 does not match'));

        final skippedTemp = records.firstWhere((r) =>
            r.ruleId == 'rule-temp-exp' &&
            r.status == AutomationExecutionStatus.skipped);
        expect(skippedTemp.reason,
            'Condition not met: Temperature 24.0°C <= 28.0°C');

        records.clear();

        // 2. Executed: schedule triggers at 07:00
        await engine.evaluate(
          virtualTime: DateTime(2026, 10, 24, 7, 0),
          devices: [sensor],
        );

        final execSched = records.firstWhere((r) =>
            r.ruleId == 'rule-sched-exp' &&
            r.status == AutomationExecutionStatus.executed);
        expect(execSched.reason, 'Triggered by schedule 07:00');

        records.clear();

        // 3. Executed trigger condition but action fails on offline device
        sensor = sensor.copyWith(currentTemperature: 29.5);
        await engine.evaluate(
          virtualTime: DateTime(2026, 10, 24, 7, 1),
          devices: [sensor],
        );

        final failTemp = records.firstWhere((r) =>
            r.ruleId == 'rule-temp-exp' &&
            r.status == AutomationExecutionStatus.failed);
        expect(failTemp.reason, 'Device socket-offline offline');

        engine.dispose();
      });
    });

    // =========================================================================
    // 8. Simulation Health Aggregator
    // =========================================================================
    group('Simulation Health Aggregator', () {
      test(
          'computes online, offline, degraded counts, healthScore and warnings',
          () async {
        final devices = [
          // Healthy online
          const SmartDevice(
            id: 'dev-1',
            name: 'Living Room Light',
            roomId: 'Living Room',
            type: DeviceType.light,
            isOn: true,
            connection: DeviceConnection.online,
          ),
          // Healthy online
          const SmartDevice(
            id: 'dev-2',
            name: 'Bedroom Light',
            roomId: 'Bedroom',
            type: DeviceType.light,
            isOn: true,
            connection: DeviceConnection.online,
          ),
          // Degraded online (weak RSSI < -85)
          const SmartDevice(
            id: 'dev-3',
            name: 'Balcony Camera',
            roomId: 'Balcony',
            type: DeviceType.security,
            isOn: true,
            connection: DeviceConnection.online,
            customData: {'rssi': -88},
          ),
          // Degraded online (low battery < 15%)
          const SmartDevice(
            id: 'dev-4',
            name: 'Front Door Sensor',
            roomId: 'Hallway',
            type: DeviceType.sensor,
            isOn: true,
            connection: DeviceConnection.online,
            customData: {'batteryLevel': 12},
          ),
          // Offline device
          const SmartDevice(
            id: 'dev-5',
            name: 'Garden Socket',
            roomId: 'Garden',
            type: DeviceType.socket,
            isOn: false,
            connection: DeviceConnection.offline,
          ),
        ];

        final aggregator = HealthAggregator(initialDevices: devices);
        final summary = aggregator.currentSummary!;

        expect(summary.totalDevices, 5);
        expect(summary.onlineDevices, 4);
        expect(summary.offlineDevices, 1);
        expect(summary.degradedDevices, 2);

        // 2 healthy (100 each), 2 degraded (50 each), 1 offline (0) => (200 + 100) / 5 = 60
        expect(summary.healthScore, 60);

        expect(summary.warnings.length, 3);
        expect(
            summary.warnings.any(
                (w) => w.contains('Garden Socket') && w.contains('offline')),
            isTrue);
        expect(
            summary.warnings.any((w) =>
                w.contains('Balcony Camera') &&
                w.contains('weak Wi-Fi signal')),
            isTrue);
        expect(
            summary.warnings.any((w) =>
                w.contains('Front Door Sensor') &&
                w.contains('battery is low')),
            isTrue);

        expect(aggregator.currentDeviceHealth.length, 5);
        final degradedHealth = aggregator.currentDeviceHealth
            .where((h) => h.status == DeviceHealthStatus.degraded);
        expect(degradedHealth.length, 2);

        aggregator.dispose();
      });
    });

    // =========================================================================
    // 9. Fault Injection Hooks
    // =========================================================================
    group('SimulationEngine Fault Injection Hooks', () {
      test('forceDeviceOffline, reconnectDevice, packetLoss and reconnectStorm',
          () async {
        final clock = VirtualClock();
        final repo = MockDeviceRepository(responseDelay: Duration.zero);
        final engine = SimulationEngine(
          clock: clock,
          repository: repo,
          initialDevices: [
            const SmartDevice(
              id: 'dev-fan',
              name: 'Living Fan',
              roomId: 'Living Room',
              type: DeviceType.fan,
              isOn: true,
            ),
            const SmartDevice(
              id: 'dev-bulb',
              name: 'Living Bulb',
              roomId: 'Living Room',
              type: DeviceType.light,
              isOn: true,
            ),
          ],
        );

        expect(engine.currentSnapshot.offlineDeviceIds, isEmpty);

        // 1. Force offline
        engine.forceDeviceOffline('dev-fan');
        expect(engine.currentSnapshot.offlineDeviceIds, contains('dev-fan'));
        expect(engine.devices.firstWhere((d) => d.id == 'dev-fan').connection,
            DeviceConnection.offline);

        // 2. Reconnect
        engine.reconnectDevice('dev-fan');
        expect(engine.currentSnapshot.offlineDeviceIds,
            isNot(contains('dev-fan')));
        expect(engine.devices.firstWhere((d) => d.id == 'dev-fan').connection,
            DeviceConnection.online);

        // 3. Set packet loss
        engine.setPacketLossRate(0.35);
        expect(engine.packetLossRate, 0.35);
        expect(repo.commandPipeline.packetLossRate, 0.35);

        // 4. Trigger reconnect storm
        await engine.triggerReconnectStorm(delayBetweenDevices: Duration.zero);

        // All devices successfully restored after storm
        for (final dev in engine.devices) {
          expect(dev.connection, DeviceConnection.online);
        }
        expect(engine.currentSnapshot.offlineDeviceIds, isEmpty);

        engine.dispose();
        await repo.dispose();
      });
    });
  });
}
