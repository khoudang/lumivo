import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/energy_report.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/energy/energy_analytics_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/scenes/scenes_service.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/command_pipeline.dart';
import 'package:lumivo/services/simulation/device_simulators/device_simulators.dart';
import 'package:lumivo/services/simulation/simulation_engine.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 7 — Simulation & Business Logic Comprehensive Audit Suite', () {
    // =========================================================================
    // SECTION 1: Command Pipeline & Device Simulators Audit
    // =========================================================================
    group('1. Command Pipeline Lifecycle, Reliability & Concurrency', () {
      test('1.1 Lifecycle transitions: queued -> pending -> confirmed/failed',
          () async {
        final records = <CommandRecord>[];
        final pipeline = CommandPipeline(simulatedLatency: Duration.zero);
        final sub = pipeline.commandStream.listen(records.add);

        // Success command
        const successCmd = DeviceCommand(
          requestId: 'cmd-audit-success',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        final resSuccess = await pipeline.execute(
          successCmd,
          onExecute: (cmd) async => CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.confirmed,
          ),
        );
        expect(resSuccess.status, CommandStatus.confirmed);
        expect(resSuccess.errorMessage, isNull);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(records.map((r) => r.status).toList(), [
          CommandStatus.queued,
          CommandStatus.pending,
          CommandStatus.confirmed,
        ]);

        // Failed command
        records.clear();
        const failedCmd = DeviceCommand(
          requestId: 'cmd-audit-failed',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: false,
        );

        final resFailed = await pipeline.execute(
          failedCmd,
          onExecute: (cmd) async => CommandResult(
            requestId: cmd.requestId,
            status: CommandStatus.failed,
            errorMessage: 'Simulated hardware rejection',
          ),
        );
        expect(resFailed.status, CommandStatus.failed);
        expect(resFailed.errorMessage, 'Simulated hardware rejection');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(records.map((r) => r.status).toList(), [
          CommandStatus.queued,
          CommandStatus.pending,
          CommandStatus.failed,
        ]);

        await sub.cancel();
        pipeline.dispose();
      });

      test('1.2 Request ID deduplication (in-flight & completed)', () async {
        final pipeline = CommandPipeline(
          simulatedLatency: const Duration(milliseconds: 20),
        );
        int invocationCount = 0;

        const command = DeviceCommand(
          requestId: 'dedup-audit-id',
          deviceId: 'light-1',
          type: DeviceCommandType.setPower,
          value: true,
        );

        // Concurrent in-flight execution with identical requestId
        final f1 = pipeline.execute(
          command,
          onExecute: (cmd) async {
            invocationCount++;
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        final f2 = pipeline.execute(
          command,
          onExecute: (cmd) async {
            invocationCount++;
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
        expect(invocationCount, 1,
            reason:
                'Concurrent in-flight duplicate must share the same future');

        // Post-completion duplicate
        final r3 = await pipeline.execute(
          command,
          onExecute: (cmd) async {
            invocationCount++;
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        expect(r3.status, CommandStatus.confirmed);
        expect(invocationCount, 1,
            reason: 'Completed duplicate must return cached result');

        pipeline.dispose();
      });

      test('1.3 Timeout handling with bounded exponential backoff retries',
          () async {
        final records = <CommandRecord>[];
        final pipeline = CommandPipeline(
          simulatedLatency: Duration.zero,
          initialBackoff: Duration.zero,
          maxRetries: 2,
          commandTimeout: const Duration(milliseconds: 15),
        );
        final sub = pipeline.commandStream.listen(records.add);

        int attempts = 0;
        final result = await pipeline.execute(
          const DeviceCommand(
            requestId: 'cmd-audit-timeout',
            deviceId: 'light-1',
            type: DeviceCommandType.setPower,
            value: true,
          ),
          onExecute: (cmd) async {
            attempts++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        expect(result.status, CommandStatus.timedOut);
        expect(attempts, 3, reason: '1 initial attempt + 2 retries = 3 total');
        expect(records.last.status, CommandStatus.timedOut);

        await sub.cancel();
        pipeline.dispose();
      });

      test('1.4 Offline device handling rejects immediately with no retries',
          () async {
        final repo = MockDeviceRepository(responseDelay: Duration.zero);
        final light =
            repo.devices.firstWhere((d) => d.type == DeviceType.light);

        repo.forceDeviceOffline(light.id);
        expect(
            repo.devices.firstWhere((d) => d.id == light.id).isOnline, isFalse);

        final result = await repo.sendCommand(DeviceCommand(
          requestId: 'cmd-offline-audit',
          deviceId: light.id,
          type: DeviceCommandType.setPower,
          value: true,
        ));

        expect(result.status, CommandStatus.failed);
        expect(result.errorMessage, contains('offline'));

        // Device remains offline and state unchanged
        expect(
            repo.devices.firstWhere((d) => d.id == light.id).isOnline, isFalse);

        // Bring back online and verify command confirmed
        repo.reconnectDevice(light.id);
        final onlineResult = await repo.sendCommand(DeviceCommand(
          requestId: 'cmd-online-audit',
          deviceId: light.id,
          type: DeviceCommandType.setPower,
          value: true,
        ));
        expect(onlineResult.status, CommandStatus.confirmed);

        await repo.dispose();
      });

      test('1.5 Concurrent commands dispatched to the same device', () async {
        final repo = MockDeviceRepository(responseDelay: Duration.zero);
        final light =
            repo.devices.firstWhere((d) => d.type == DeviceType.light);

        // Dispatch 10 concurrent commands with unique requestIds to the same device
        final commands = List.generate(
          10,
          (i) => DeviceCommand(
            requestId: 'concurrent-light-$i',
            deviceId: light.id,
            type: DeviceCommandType.setBrightness,
            value: 10 + i * 8, // 10, 18, 26, ... 82
          ),
        );

        final results = await Future.wait(
          commands.map((cmd) => repo.sendCommand(cmd)),
        );

        expect(results.length, 10);
        for (final res in results) {
          expect(res.status, CommandStatus.confirmed);
        }

        final updated = repo.devices.firstWhere((d) => d.id == light.id);
        expect(updated.isOn, isTrue);
        expect(updated.brightness, greaterThanOrEqualTo(10));
        expect(updated.brightness, lessThanOrEqualTo(100));

        await repo.dispose();
      });

      test('1.6 Resource cleanup in dispose cancels in-flight completers',
          () async {
        final pipeline = CommandPipeline(
          simulatedLatency: const Duration(seconds: 1),
        );

        final future = pipeline.execute(
          const DeviceCommand(
            requestId: 'cmd-in-flight-dispose',
            deviceId: 'dev-1',
            type: DeviceCommandType.setPower,
            value: true,
          ),
          onExecute: (cmd) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            return CommandResult(
              requestId: cmd.requestId,
              status: CommandStatus.confirmed,
            );
          },
        );

        // Dispose while in flight
        pipeline.dispose();

        // The future must complete cleanly with cancelled status rather than hanging indefinitely
        final result = await future;
        expect(result.status, CommandStatus.cancelled);
        expect(result.errorMessage, contains('disposed'));

        // Subsequent execute on disposed pipeline returns cancelled immediately
        final postDisposeResult = await pipeline.execute(
          const DeviceCommand(
            requestId: 'cmd-post-dispose',
            deviceId: 'dev-1',
            type: DeviceCommandType.setPower,
            value: false,
          ),
        );
        expect(postDisposeResult.status, CommandStatus.cancelled);
      });
    });

    group('1.7 Device Simulators Wattage & Telemetry Bounds Audit', () {
      test(
          'BulbSimulator deterministic wattage (9W * brightness / 100, 0.2W off)',
          () {
        expect(BulbSimulator.calculatePower(isOn: false, brightness: 100), 0.2);
        expect(BulbSimulator.calculatePower(isOn: true, brightness: 100), 9.0);
        expect(BulbSimulator.calculatePower(isOn: true, brightness: 50), 4.5);
        expect(BulbSimulator.calculatePower(isOn: true, brightness: 0), 0.0);
      });

      test(
          'FanSimulator deterministic wattage (Low: 15W, Med: 35W, High: 55W, Off: 0.5W)',
          () {
        expect(FanSimulator.calculatePower(isOn: false, speed: FanSpeed.high),
            0.5);
        expect(
            FanSimulator.calculatePower(isOn: true, speed: FanSpeed.low), 15.0);
        expect(FanSimulator.calculatePower(isOn: true, speed: FanSpeed.medium),
            35.0);
        expect(FanSimulator.calculatePower(isOn: true, speed: FanSpeed.high),
            55.0);
      });

      test(
          'AcSimulator deterministic wattage (1200W on, 5W off) & target clamping',
          () {
        expect(AcSimulator.calculatePower(isOn: true), 1200.0);
        expect(AcSimulator.calculatePower(isOn: false), 5.0);

        final ac = SmartDevice(
          id: 'ac-audit',
          name: 'AC Audit',
          roomId: 'Living Room',
          type: DeviceType.ac,
          isOn: true,
          targetTemperature: 24.0,
          currentTemperature: 28.0,
        );
        final sim = AcSimulator(ac);

        sim.setTargetTemperature(12.0); // Below 16
        expect(sim.device.targetTemperature, 16.0);

        sim.setTargetTemperature(35.0); // Above 30
        expect(sim.device.targetTemperature, 30.0);
      });

      test('SocketSimulator deterministic wattage (120W on, 0W off)', () {
        expect(SocketSimulator.calculatePower(isOn: true), 120.0);
        expect(SocketSimulator.calculatePower(isOn: false), 0.0);
      });

      test('CurtainSimulator deterministic wattage (15W moving, 0.5W idle)',
          () {
        final curtain = SmartDevice(
          id: 'curtain-audit',
          name: 'Curtain Audit',
          roomId: 'Bedroom',
          type: DeviceType.curtain,
          isOn: true,
          position: 0,
        );
        final sim = CurtainSimulator(curtain, speedPercentPerSecond: 20.0);

        expect(sim.isMoving, isFalse);
        expect(sim.powerUsageWatts, 0.5);

        sim.setTargetPosition(60);
        expect(sim.isMoving, isTrue);
        expect(sim.powerUsageWatts, 15.0);

        // Advance 3 seconds -> moves 20 * 3 = 60%
        final updated = sim.tick(const Duration(seconds: 3));
        expect(updated.position, 60);
        expect(sim.isMoving, isFalse);
        expect(sim.powerUsageWatts, 0.5);
      });

      test('LockSimulator deterministic wattage (0.1W locked, 0.8W unlocked)',
          () {
        final lock = SmartDevice(
          id: 'lock-audit',
          name: 'Lock Audit',
          roomId: 'Front Door',
          type: DeviceType.lock,
          isOn: true,
          isLocked: true,
        );
        final sim =
            LockSimulator(lock, autoLockDelay: const Duration(seconds: 10));

        expect(sim.powerUsageWatts, 0.1);
        sim.unlock();
        expect(sim.powerUsageWatts, 0.8);
        expect(sim.device.isLocked, isFalse);

        // Tick 11 seconds -> auto locks
        final updated = sim.tick(const Duration(seconds: 11));
        expect(updated.isLocked, isTrue);
        expect(sim.powerUsageWatts, 0.1);
      });

      test(
          'SensorSimulator & AcSimulator strict telemetry bounds (temp 16-32°C, humidity 20-90%)',
          () {
        final sensor = SmartDevice(
          id: 'sensor-bounds',
          name: 'Sensor Bounds',
          roomId: 'Living Room',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 25.0,
          currentHumidity: 50.0,
        );
        final sim = SensorSimulator(sensor);

        // Inject out-of-bounds high values: 50°C and 99% humidity
        sim.forcedTemperature = 50.0;
        sim.forcedHumidity = 99.0;
        var ticked = sim.tick(const Duration(seconds: 1));
        expect(ticked.currentTemperature, 32.0,
            reason: 'Sensor temperature must be strictly clamped to <= 32°C');
        expect(ticked.currentHumidity, 90.0,
            reason: 'Sensor humidity must be strictly clamped to <= 90%');

        // Inject out-of-bounds low values: 10°C and 5% humidity
        sim.forcedTemperature = 10.0;
        sim.forcedHumidity = 5.0;
        ticked = sim.tick(const Duration(seconds: 1));
        expect(ticked.currentTemperature, 16.0,
            reason: 'Sensor temperature must be strictly clamped to >= 16°C');
        expect(ticked.currentHumidity, 20.0,
            reason: 'Sensor humidity must be strictly clamped to >= 20%');

        // Diurnal curve across all 24 hours must also remain strictly bounded
        for (var h = 0; h < 24; h++) {
          final time = DateTime(2026, 10, 20, h, 0);
          final temp = SensorSimulator.computeDiurnalTemperature(time);
          final humidity = SensorSimulator.computeDiurnalHumidity(time);
          expect(temp, inInclusiveRange(16.0, 32.0));
          expect(humidity, inInclusiveRange(20.0, 90.0));
        }

        // AcSimulator currentTemperature bounded in [16, 32]
        final ac = SmartDevice(
          id: 'ac-bounds',
          name: 'AC Bounds',
          roomId: 'Bedroom',
          type: DeviceType.ac,
          isOn: false,
          currentTemperature: 31.9,
        );
        final acSim = AcSimulator(ac);
        // Drift with extreme ambient 45°C
        final acTicked = acSim.tick(
          const Duration(minutes: 60),
          context: {'ambientTemperature': 45.0},
        );
        expect(acTicked.currentTemperature, inInclusiveRange(16.0, 32.0));
      });
    });

    // =========================================================================
    // SECTION 2: Automation & Scene Engine Audit
    // =========================================================================
    group('2. Automation & Scene Engine Audit', () {
      test(
          '2.1 Rule evaluation under accelerated virtual time (1x, 2x, 5x, 10x)',
          () async {
        final clock = VirtualClock(
          initialTime: DateTime(2026, 10, 20, 8, 29, 50),
          initialMultiplier: 1.0,
        );
        int executionCount = 0;

        final engine = AutomationEngine(
          onDispatchAction: (action) async {
            executionCount++;
          },
        );

        engine.addRule(AutomationRule(
          id: 'schedule-accel',
          name: 'Morning Schedule',
          isEnabled: true,
          triggerType: TriggerType.schedule,
          timeOfDay: '08:30',
          daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
          actions: const [
            DeviceAction(
              deviceId: 'light-1',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        ));

        // Multiplier progression: 1x -> 2x -> 5x -> 10x
        for (final mult in [1.0, 2.0, 5.0, 10.0]) {
          clock.setMultiplier(mult);
          expect(clock.timeMultiplier, mult);
        }

        // Step virtual clock into 08:30:00
        clock.advance(const Duration(seconds: 10));
        expect(clock.now.minute, 30);

        await engine.evaluate(
          virtualTime: clock.now,
          devices: const [],
        );
        expect(executionCount, 1,
            reason:
                'Rule must execute when virtual clock enters target minute');

        // Step within same minute (08:30:30) under 10x acceleration -> deduplication prevents re-fire
        clock.advance(const Duration(seconds: 30));
        expect(clock.now.minute, 30);

        await engine.evaluate(
          virtualTime: clock.now,
          devices: const [],
        );
        expect(executionCount, 1,
            reason:
                'Minute deduplication must prevent double firing within the same minute');

        engine.dispose();
        clock.dispose();
      });

      test('2.2 Execution loop prevention (recursion depth limit)', () async {
        late final AutomationEngine engine;
        final rules = List.generate(
          5,
          (i) => AutomationRule(
            id: 'cascade-level-$i',
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

        int currentLevel = 0;
        final testTime = DateTime(2026, 10, 24, 10, 0, 0);

        engine = AutomationEngine(
          initialRules: [rules[0]],
          onDispatchAction: (action) async {
            currentLevel++;
            if (currentLevel < rules.length) {
              engine.setRules([rules[currentLevel]]);
              await engine.evaluate(virtualTime: testTime, devices: const []);
            }
          },
        );

        await engine.evaluate(virtualTime: testTime, devices: const []);

        final loopPreventedRecords = engine.executionHistory
            .where((r) => r.status == AutomationExecutionStatus.loopPrevented)
            .toList();

        expect(loopPreventedRecords.isNotEmpty, isTrue,
            reason:
                'Recursion depth limit must catch and halt recursion cascades');

        engine.dispose();
      });

      test('2.3 Frequency limit loop prevention (5 triggers / sec)', () async {
        final records = <AutomationExecutionRecord>[];
        final engine = AutomationEngine();
        final sub = engine.executionRecordStream.listen(records.add);

        final rule = AutomationRule(
          id: 'rapid-sensor-rule',
          name: 'Rapid Sensor Trigger',
          isEnabled: true,
          triggerType: TriggerType.sensorThreshold,
          sensorDeviceId: 'temp-1',
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
        engine.addRule(rule);

        final coolSensor = SmartDevice(
          id: 'temp-1',
          name: 'Temp Sensor',
          roomId: 'Living Room',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 25.0, // Resets hysteresis (< 28 - 0.5)
        );

        final hotSensor = SmartDevice(
          id: 'temp-1',
          name: 'Temp Sensor',
          roomId: 'Living Room',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 30.0, // Triggers (> 28)
        );

        final now = DateTime(2026, 10, 20, 10, 0, 0);

        // Alternate cool and hot sensors to trigger rule 6 times within 1 second
        for (int i = 0; i < 6; i++) {
          final t = now.add(Duration(milliseconds: i * 50));
          // Reset hysteresis
          await engine.evaluate(virtualTime: t, devices: [coolSensor]);
          // Trigger condition
          await engine.evaluate(virtualTime: t, devices: [hotSensor]);
        }

        final loopPrevented = records
            .where((r) => r.status == AutomationExecutionStatus.loopPrevented)
            .toList();

        expect(loopPrevented.isNotEmpty, isTrue,
            reason:
                'Triggering > 5 times within 1 second must trigger loop protection');

        await sub.cancel();
        engine.dispose();
      });

      test(
          '2.4 Execution history & activity history strictly capped at 100 entries',
          () async {
        final engine = AutomationEngine(
          maxExecutionHistory: 100,
        );

        expect(engine.maxExecutionHistory, 100);

        final rule = AutomationRule(
          id: 'history-test-rule',
          name: 'History Test',
          isEnabled: true,
          triggerType: TriggerType.schedule,
          timeOfDay: '08:30',
          daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
          actions: const [
            DeviceAction(
              deviceId: 'light-1',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );
        engine.addRule(rule);

        // Emit 150 evaluations across different virtual days
        for (int i = 0; i < 150; i++) {
          final time = DateTime(2026, 1, 1, 8, 30).add(Duration(days: i));
          await engine.evaluate(
            virtualTime: time,
            devices: const [],
          );
        }

        expect(engine.executionHistory.length, lessThanOrEqualTo(100),
            reason: 'Execution history must be strictly capped at 100 entries');
        expect(engine.activityHistory.length, lessThanOrEqualTo(100),
            reason: 'Activity history must be strictly capped at 100 entries');

        engine.dispose();
      });

      test('2.5 Deleted / missing device handling in AutomationEngine',
          () async {
        final engine = AutomationEngine(
          onDispatchAction: (action) async {
            if (action.deviceId == 'deleted-light') {
              throw StateError('Device deleted-light does not exist');
            }
          },
        );

        engine.addRule(AutomationRule(
          id: 'rule-dangling-device',
          name: 'Dangling Device Action',
          isEnabled: true,
          triggerType: TriggerType.schedule,
          timeOfDay: '09:00',
          daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
          actions: const [
            DeviceAction(
              deviceId: 'deleted-light',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        ));

        // Evaluating must NOT throw unhandled exception
        await expectLater(
          engine.evaluate(
            virtualTime: DateTime(2026, 10, 20, 9, 0),
            devices: const [],
          ),
          completes,
        );

        final lastRecord = engine.executionHistory.last;
        expect(lastRecord.status, AutomationExecutionStatus.failed);
        expect(lastRecord.reason, contains('deleted-light'));

        engine.dispose();
      });

      test('2.6 Deleted / missing device handling in ScenesService', () async {
        final repo = MockDeviceRepository(responseDelay: Duration.zero);
        final scenesService = ScenesService(initialScenes: []);

        const scene = Scene(
          id: 'scene-dangling',
          name: 'Dangling Scene',
          actions: [
            DeviceAction(
              deviceId: 'non-existent-device-xyz',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );

        // Executing scene targeting non-existent device must NOT throw unhandled exceptions
        await expectLater(
          scenesService.executeScene(scene, repo),
          completes,
        );

        expect(scenesService.activityHistory.isNotEmpty, isTrue);

        scenesService.dispose();
        await repo.dispose();
      });

      test('2.7 ScenePreview accurately predicts command dispatch results', () {
        final onlineLight = SmartDevice(
          id: 'light-online',
          name: 'Kitchen Light',
          roomId: 'Kitchen',
          type: DeviceType.light,
          isOn: false,
          connection: DeviceConnection.online,
        );

        final offlineFan = SmartDevice(
          id: 'fan-offline',
          name: 'Living Fan',
          roomId: 'Living Room',
          type: DeviceType.fan,
          isOn: false,
          connection: DeviceConnection.offline,
        );

        const scene = Scene(
          id: 'scene-preview-audit',
          name: 'Preview Audit Scene',
          actions: [
            // Target 1: Online device changing state
            DeviceAction(
              deviceId: 'light-online',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
            // Target 2: Offline device (cannot change)
            DeviceAction(
              deviceId: 'fan-offline',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
            // Target 3: Missing/deleted device
            DeviceAction(
              deviceId: 'deleted-device-abc',
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
        );

        final previewItems = ScenePreviewEngine.computePreview(
          scene: scene,
          devices: [onlineLight, offlineFan],
        );

        expect(previewItems.length, 3);

        // 1. Online device: executable and willChange is true
        expect(previewItems[0].isExecutable, isTrue);
        expect(previewItems[0].isDeviceOffline, isFalse);
        expect(previewItems[0].isDeviceMissing, isFalse);
        expect(previewItems[0].willChange, isTrue);

        // 2. Offline device: isDeviceOffline is true, willChange is false
        expect(previewItems[1].isExecutable, isFalse);
        expect(previewItems[1].isDeviceOffline, isTrue);
        expect(previewItems[1].isDeviceMissing, isFalse);
        expect(previewItems[1].willChange, isFalse);

        // 3. Missing device: isDeviceMissing is true, willChange is false
        expect(previewItems[2].isExecutable, isFalse);
        expect(previewItems[2].isDeviceOffline, isFalse);
        expect(previewItems[2].isDeviceMissing, isTrue);
        expect(previewItems[2].willChange, isFalse);
      });
    });

    // =========================================================================
    // SECTION 3: Energy Analytics & CSV Audit
    // =========================================================================
    group('3. Energy Analytics Math, Cost Formulas & CSV Export Audit', () {
      test(
          '3.1 Exact power-to-energy integration: energy (kWh) = watts * delta_t / 3600000',
          () {
        final service = EnergyAnalyticsService();

        // 1000W for exactly 1 hour = 1.0 kWh
        service.recordSample(
          timestamp: DateTime(2026, 10, 20, 10, 0),
          powerWatts: 1000.0,
          elapsedDuration: const Duration(hours: 1),
          tariffRate: 0.16,
        );
        expect(service.samples.last.energyKWh, closeTo(1.0, 0.0001));

        // 500W for exactly 2 hours = 1.0 kWh
        service.recordSample(
          timestamp: DateTime(2026, 10, 20, 12, 0),
          powerWatts: 500.0,
          elapsedDuration: const Duration(hours: 2),
          tariffRate: 0.16,
        );
        expect(service.samples.last.energyKWh, closeTo(1.0, 0.0001));

        // 3600W for 1 second = 3600 * 1 / 3,600,000 = 0.001 kWh
        service.recordSample(
          timestamp: DateTime(2026, 10, 20, 12, 0, 1),
          powerWatts: 3600.0,
          elapsedDuration: const Duration(seconds: 1),
          tariffRate: 0.16,
        );
        expect(service.samples.last.energyKWh, closeTo(0.001, 0.00001));

        service.dispose();
      });

      test('3.2 Tariff cost calculation and room/device breakdowns', () {
        final service = EnergyInsightsService(defaultTariff: 0.16);

        final devices = [
          SmartDevice(
            id: 'ac-1',
            name: 'Master AC',
            roomId: 'Bedroom',
            type: DeviceType.ac,
            isOn: true,
            powerUsageWatts: 1000.0,
          ),
          SmartDevice(
            id: 'bulb-1',
            name: 'Living Light',
            roomId: 'Living Room',
            type: DeviceType.light,
            isOn: true,
            powerUsageWatts: 20.0,
          ),
          SmartDevice(
            id: 'bulb-off',
            name: 'Kitchen Light',
            roomId: 'Kitchen',
            type: DeviceType.light,
            isOn: false,
            powerUsageWatts: 0.2,
          ),
        ];

        final report = service.generateReport(
          devices: devices,
          period: 'day', // 24 hours
          tariff: 0.16,
        );

        // Master AC: 1000W * 24h = 24.0 kWh -> $3.84
        // Living Light: 20W * 24h = 0.48 kWh -> $0.0768
        // Kitchen Light (Off): 0W active -> 0.0 kWh -> $0.00
        expect(report.totalKwh, closeTo(24.48, 0.01));
        expect(report.totalCost, closeTo(3.9168, 0.01));

        // Breakdowns must be sorted descending by kWh
        expect(report.deviceBreakdown.first.name, 'Master AC');
        expect(report.deviceBreakdown.first.kwh, 24.0);
        expect(report.roomBreakdown.first.name, 'Bedroom');
        expect(report.roomBreakdown.first.kwh, 24.0);
      });

      test(
          '3.3 CSV export format: RFC 4180 headers, timestamps, units, quote escaping, notice banner',
          () {
        const insightsService = EnergyInsightsService();

        final report = EnergyReport(
          period: 'day',
          totalKwh: 24.48,
          totalCost: 3.9168,
          tariff: 0.16,
          previousPeriodKwh: 23.0,
          percentChange: 6.43,
          deviceBreakdown: const [
            EnergyBreakdownItem(
              id: 'dev-quote',
              name: 'Living "Chandelier" Light',
              category: 'device',
              wattage: 100.0,
              kwh: 2.4,
              cost: 0.384,
            ),
          ],
          roomBreakdown: const [
            EnergyBreakdownItem(
              id: 'room-1',
              name: 'Living, Dining & Hall',
              category: 'room',
              wattage: 100.0,
              kwh: 2.4,
              cost: 0.384,
            ),
          ],
          generatedAt: DateTime(2026, 10, 25, 14, 30),
        );

        // 1. Audit EnergyInsightsService.exportEnergyCsv
        final csv1 = insightsService.exportEnergyCsv(report);
        expect(
            csv1, contains('# Notice: All figures are simulated estimates.'));
        expect(
            csv1,
            contains(
                'Period,Category,Name,Wattage_W,Consumption_kWh,Estimated_Cost,Tariff'));
        // Verify quote escaping: "Living ""Chandelier"" Light"
        expect(csv1, contains('"Living ""Chandelier"" Light"'));
        // Verify comma escaping: "Living, Dining & Hall"
        expect(csv1, contains('"Living, Dining & Hall"'));

        // 2. Audit EnergyInsightsEngine.exportToCsv
        final csv2 = EnergyInsightsEngine.exportToCsv(report);
        expect(
            csv2,
            contains(
                'Timestamp,Category,ID,Name,Power (W),Energy (kWh),Cost (\$),Tariff (\$/kWh)'));
        expect(csv2, contains('"Living ""Chandelier"" Light"'));
        expect(csv2, contains('2026-10-25T14:30:00.000'));
      });
    });

    // =========================================================================
    // SECTION 4: Large-Scale Stress Audit
    // =========================================================================
    group(
        '4. Large-Scale Stress Audit (100+ Devices, 20+ Rooms, 100+ Automations, 1000+ Events)',
        () {
      test('4.1 System stability and memory bounding under extreme scale',
          () async {
        final storage = StorageAdapterImpl();
        final persistence = HomePersistenceManager(storage: storage);

        // Generate 25 distinct rooms
        final rooms = List.generate(
          25,
          (i) => Room(
            id: 'stress-room-$i',
            name: 'Stress Zone $i',
            iconName: 'room_icon_$i',
          ),
        );

        // Generate 120 smart devices across 25 rooms
        final types = [
          DeviceType.light,
          DeviceType.fan,
          DeviceType.ac,
          DeviceType.socket,
          DeviceType.curtain,
          DeviceType.lock,
          DeviceType.sensor,
        ];

        final devices = List.generate(
          120,
          (i) => SmartDevice(
            id: 'stress-dev-$i',
            name: 'Device #$i',
            roomId: rooms[i % rooms.length].id,
            type: types[i % types.length],
            isOn: i % 2 == 0,
            brightness: 75,
            powerUsageWatts: i % 2 == 0 ? 30.0 : 0.5,
            connection: DeviceConnection.online,
          ),
        );

        // Generate 110 automation rules
        final automations = List.generate(
          110,
          (i) => AutomationRule(
            id: 'stress-auto-$i',
            name: 'Stress Rule #$i',
            isEnabled: true,
            triggerType: TriggerType.schedule,
            timeOfDay: '${(i % 24).toString().padLeft(2, '0')}:00',
            daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
            actions: [
              DeviceAction(
                deviceId: devices[i % devices.length].id,
                commandType: DeviceCommandType.setPower,
                value: true,
              ),
            ],
          ),
        );

        // Generate 1000 ActivityEvents
        final now = DateTime(2026, 10, 25, 12, 0);
        final events = List.generate(
          1000,
          (i) => ActivityEvent(
            id: 'stress-evt-$i',
            title: 'Telemetry Tick #$i',
            description: 'Scale stress test event',
            timestamp: now.add(Duration(seconds: i)),
            deviceId: devices[i % devices.length].id,
            severity: ActivitySeverity.info,
            source: 'system',
          ),
        );

        await persistence.saveRooms(rooms);
        await persistence.saveDevices(devices);
        await persistence.saveAutomations(automations);
        await persistence.saveActivityEvents(events);

        // In-memory repo without synchronous persistence writes during clock tick
        final repo = MockDeviceRepository(
          responseDelay: Duration.zero,
          initialDevices: devices,
        );

        final clock = VirtualClock(
          initialTime: DateTime(2026, 10, 25, 0, 0),
          autoStart: false,
        );

        final engine = SimulationEngine(
          clock: clock,
          repository: repo,
          initialDevices: devices,
          initialRules: automations,
          autoStart: false,
        );

        expect(engine.devices.length, 120);
        expect(engine.automationEngine.rules.length, 110);

        // Advance virtual clock across 24 hours (triggers schedules)
        final sw = Stopwatch()..start();
        for (int h = 0; h < 24; h++) {
          clock.advance(const Duration(hours: 1));
          await pumpEventQueue();
        }
        sw.stop();

        // Performance check: 24 hour simulation ticks across 120 devices & 110 rules completes in < 500ms
        expect(sw.elapsedMilliseconds, lessThan(500));

        // Execution and activity history must remain strictly bounded to <= 100
        expect(engine.automationEngine.executionHistory.length,
            lessThanOrEqualTo(100));
        expect(engine.automationEngine.activityHistory.length,
            lessThanOrEqualTo(100));

        // Telemetry snapshot must be coherent
        final snapshot = engine.currentSnapshot;
        expect(snapshot.devices.length, 120);
        expect(snapshot.totalPowerWatts, greaterThan(0.0));

        // Verify loaded 1000 activity events from persistence
        final persistedState = await persistence.loadHomeState();
        expect(persistedState.activityEvents.length, 1000);

        // Proper resource cleanup in dispose
        engine.dispose();
        clock.dispose();
        await repo.dispose();
      });
    });
  });
}
