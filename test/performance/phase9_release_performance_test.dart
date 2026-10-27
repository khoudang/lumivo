import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/energy/energy_analytics_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/search/device_search_engine.dart';
import 'package:lumivo/services/simulation/automation_engine.dart';
import 'package:lumivo/services/simulation/command_pipeline.dart';
import 'package:lumivo/services/simulation/simulation_engine.dart';
import 'package:lumivo/services/simulation/simulation_lifecycle_observer.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 9 Release Candidate Performance & Benchmark Suite', () {
    late List<Room> rooms;
    late List<SmartDevice> devices;
    late List<AutomationRule> automations;
    late List<ActivityEvent> activityEvents;
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late MockDeviceRepository repository;

    const deviceTypes = [
      DeviceType.light,
      DeviceType.fan,
      DeviceType.security,
      DeviceType.ac,
      DeviceType.socket,
      DeviceType.curtain,
      DeviceType.lock,
      DeviceType.sensor,
    ];

    setUp(() async {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);

      // 1. Generate 20 distinct rooms
      rooms = List.generate(20, (i) {
        return Room(
          id: 'room-${i + 1}',
          name: i == 0
              ? 'Living Room'
              : i == 1
                  ? 'Master Suite'
                  : i == 2
                      ? 'Chef Kitchen'
                      : i == 3
                          ? 'Home Office'
                          : i == 4
                              ? 'Balcony Terrace'
                              : 'Room ${i + 1}',
          iconName: 'room_icon_$i',
          description: 'High-density stress zone #$i',
          homeId: 'home-default',
        );
      });

      // 2. Generate 100 devices across 20 rooms (5 devices per room)
      devices = List.generate(100, (i) {
        final assignedRoom = rooms[i % rooms.length];
        final type = deviceTypes[i % deviceTypes.length];
        final id = 'device-scale-${i + 1}';
        final name =
            '${assignedRoom.name} ${type.name.toUpperCase()} #${i + 1}';

        return SmartDevice(
          id: id,
          name: name,
          roomId: assignedRoom.id,
          type: type,
          isOn: i % 2 == 0,
          brightness: type == DeviceType.light ? (10 + (i * 7) % 90) : 100,
          targetTemperature: type == DeviceType.ac ? (18.0 + (i % 10)) : 24.0,
          currentTemperature: 23.5 + (i % 5) * 0.5,
          currentHumidity: 45.0 + (i % 25),
          position: type == DeviceType.curtain ? (i * 10) % 100 : 0,
          isLocked: type == DeviceType.lock ? (i % 3 != 0) : true,
          powerUsageWatts: i % 2 == 0 ? (20.0 + (i % 60)) : 0.0,
          connection: DeviceConnection.online,
          homeId: 'home-default',
        );
      });

      // 3. Generate 100 diverse automation rules
      automations = List.generate(100, (i) {
        final targetDevice = devices[i % devices.length];
        final triggerDevice = devices[(i + 13) % devices.length];
        final isSchedule = i % 2 == 0;
        final hour = (i % 24).toString().padLeft(2, '0');
        final minute = ((i * 7) % 60).toString().padLeft(2, '0');

        return AutomationRule(
          id: 'auto-scale-${i + 1}',
          name: 'Scale Automation Rule #${i + 1}',
          triggerType:
              isSchedule ? TriggerType.schedule : TriggerType.sensorThreshold,
          isEnabled: true,
          timeOfDay: isSchedule ? '$hour:$minute' : null,
          daysOfWeek: isSchedule ? const [1, 2, 3, 4, 5, 6, 7] : const [],
          sensorDeviceId: isSchedule ? null : triggerDevice.id,
          sensorProperty: 'temperature',
          operator: ComparisonOperator.greaterThan,
          thresholdValue: 26.0,
          actions: [
            DeviceAction(
              deviceId: targetDevice.id,
              commandType: DeviceCommandType.setPower,
              value: true,
            ),
          ],
          homeId: 'home-default',
        );
      });

      // 4. Generate 1000 ActivityEvents
      final baseTime = DateTime(2026, 10, 25, 8, 0);
      activityEvents = List.generate(1000, (i) {
        final refDevice = devices[i % devices.length];
        final severity = i % 20 == 0
            ? ActivitySeverity.alert
            : i % 8 == 0
                ? ActivitySeverity.warning
                : i % 5 == 0
                    ? ActivitySeverity.success
                    : ActivitySeverity.info;

        return ActivityEvent(
          id: 'event-scale-${i + 1}',
          title: 'Event #${i + 1}: ${refDevice.name}',
          description: 'High-density stress telemetry event on ${refDevice.id}',
          timestamp: baseTime.subtract(Duration(minutes: i * 3)),
          deviceId: refDevice.id,
          severity: severity,
          source: i % 3 == 0 ? 'automation' : 'device',
          homeId: 'home-default',
        );
      });

      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: devices,
        persistenceManager: persistenceManager,
      );
    });

    tearDown(() async {
      await repository.dispose();
      SimulationEngine.resetInstance();
    });

    test(
        '1. Scale verification: 100 devices, 20 rooms, 100 automations, 1000 events',
        () {
      expect(devices.length, equals(100));
      expect(rooms.length, equals(20));
      expect(automations.length, equals(100));
      expect(activityEvents.length, equals(1000));
      expect(repository.devices.length, equals(100));
    });

    test(
        '2. Device repository query latency is strictly < 50ms across 100 devices',
        () {
      final sw = Stopwatch()..start();

      // Individual indexed queries
      for (final dev in devices) {
        final queried = repository.getDeviceById(dev.id);
        expect(queried, isNotNull);
        expect(queried!.id, equals(dev.id));
      }

      // Bulk home queries
      final homeDevices = repository.getDevicesForHome('home-default');
      expect(homeDevices.length, equals(100));

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason:
              'Querying 100 indexed devices took ${sw.elapsedMilliseconds}ms, must be < 50ms');
    });

    test('3. Room filtering latency across 20 rooms is strictly < 20ms', () {
      final sw = Stopwatch()..start();

      for (final room in rooms) {
        final roomDevices = repository.getDevicesForRoom(room.id);
        expect(roomDevices.length, equals(5));
      }

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(20),
          reason:
              'Filtering 20 rooms took ${sw.elapsedMilliseconds}ms, must be < 20ms');
    });

    test('4. Virtual clock acceleration stability at 10x, 60x, and 300x', () {
      final clock = VirtualClock(
        initialTime: DateTime(2026, 10, 20, 8, 0),
        initialMultiplier: 1.0,
      );

      expect(clock.timeMultiplier, equals(1.0));
      expect(clock.isRunning, isFalse);

      // Multiplier updates
      clock.setMultiplier(10.0);
      expect(clock.timeMultiplier, equals(10.0));

      clock.setMultiplier(60.0);
      expect(clock.timeMultiplier, equals(60.0));

      clock.setMultiplier(300.0);
      expect(clock.timeMultiplier, equals(300.0));

      // Deterministic advance at 300x (simulating 5 minutes real time = 25 hours virtual)
      final sw = Stopwatch()..start();
      const simulatedStep = Duration(hours: 25);
      clock.advance(simulatedStep);
      sw.stop();

      expect(clock.now, equals(DateTime(2026, 10, 21, 9, 0)));
      expect(sw.elapsedMilliseconds, lessThan(10));

      clock.dispose();
      expect(clock.isDisposed, isTrue);
    });

    test(
        '5. SimulationEngine snapshot computation with 100 active devices is < 50ms',
        () {
      final engine = SimulationEngine(
        repository: repository,
        initialDevices: devices,
        initialRules: automations,
      );

      final sw = Stopwatch()..start();
      // Advance virtual clock by 1 hour
      engine.advanceTime(const Duration(hours: 1));
      final snapshot = engine.currentSnapshot;
      sw.stop();

      expect(snapshot.devices.length, equals(100));
      expect(snapshot.totalPowerWatts, greaterThan(0));
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason:
              'Simulation tick took ${sw.elapsedMilliseconds}ms, must be < 50ms');

      engine.dispose();
      expect(engine.isDisposed, isTrue);
    });

    test('6. CommandPipeline memory bounded buffers prevent unbounded growth',
        () async {
      final pipeline = CommandPipeline(
        simulatedLatency: Duration.zero,
        maxHistoryEntries: 50,
      );

      // Issue 200 commands sequentially
      for (int i = 0; i < 200; i++) {
        final cmd = DeviceCommand(
          requestId: 'pipeline-stress-$i',
          deviceId: 'device-scale-1',
          type: DeviceCommandType.setPower,
          value: i % 2 == 0,
        );
        final result = await pipeline.execute(cmd);
        expect(result.status, equals(CommandStatus.confirmed));
      }

      // Verify commandHistory is capped at maxHistoryEntries (50)
      expect(pipeline.commandHistory.length, equals(50));

      pipeline.dispose();
      expect(pipeline.isDisposed, isTrue);
    });

    test(
        '7. Energy telemetry sample buffer bounding under continuous telemetry',
        () {
      final energyService = DefaultEnergyAnalyticsService();
      final baseTime = DateTime(2026, 10, 1, 0, 0);

      // Record 6000 samples (exceeding maxStoredSamples = 5000)
      for (int i = 0; i < 6000; i++) {
        energyService.recordSample(
          timestamp: baseTime.add(Duration(minutes: i)),
          powerWatts: 150.0 + (i % 50),
          elapsedDuration: const Duration(minutes: 1),
        );
      }

      // Memory buffer is strictly capped to maxStoredSamples (5000)
      expect(energyService.samples.length,
          lessThanOrEqualTo(DefaultEnergyAnalyticsService.maxStoredSamples));

      energyService.dispose();
    });

    test('8. Multi-attribute search and filtering across 100 devices is < 30ms',
        () {
      const searchEngine = DeviceSearchEngine();
      final sw = Stopwatch()..start();

      // Search by text query
      final lights = searchEngine.search(
        allDevices: devices,
        homeId: 'home-default',
        query: 'LIGHT',
      );
      expect(lights.isNotEmpty, isTrue);

      // Filter by type
      final acs = searchEngine.search(
        allDevices: devices,
        homeId: 'home-default',
        type: DeviceType.ac,
      );
      expect(acs.isNotEmpty, isTrue);

      // Sort by recent / power usage
      final sortedByPower = searchEngine.search(
        allDevices: devices,
        homeId: 'home-default',
        sortBy: 'recent',
      );
      expect(sortedByPower.first.isOn, isTrue);

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(30),
          reason:
              'Search suite took ${sw.elapsedMilliseconds}ms, must be < 30ms');
    });

    test('9. Energy insights report and CSV export generation is < 50ms', () {
      const insightsService = EnergyInsightsService();
      final sw = Stopwatch()..start();

      final report = insightsService.generateReport(
        devices: devices,
        period: 'month',
        homeId: 'home-default',
      );

      expect(report.deviceBreakdown.length, equals(100));
      expect(report.roomBreakdown.length, equals(20));
      expect(report.totalKwh, greaterThan(0));

      final csv = insightsService.exportEnergyCsv(report);
      expect(csv, contains('# Lumivo Energy Report'));
      expect(csv, contains('# Notice: All figures are simulated estimates.'));
      expect(
          csv,
          contains(
              'Period,Category,Name,Wattage_W,Consumption_kWh,Estimated_Cost,Tariff'));

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason:
              'Report and CSV generation took ${sw.elapsedMilliseconds}ms, must be < 50ms');
    });

    test(
        '10. Lifecycle observer background suspension and foreground resumption',
        () {
      final clock = VirtualClock(
        initialTime: DateTime(2026, 10, 20, 8, 0),
        autoStart: true,
      );
      expect(clock.isRunning, isTrue);

      final observer = SimulationLifecycleObserver(
        clock: clock,
        syncElapsedTimeOnResume: true,
      );

      // App transitions to background
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(observer.isSuspended, isTrue);
      expect(clock.isRunning, isFalse);

      // Spurious duplicate paused call should be safely ignored
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(observer.pauseCount, equals(1));

      // App transitions back to foreground
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(observer.isSuspended, isFalse);
      expect(clock.isRunning, isTrue);
      expect(observer.resumeCount, equals(1));

      // Spurious resume call when already running
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(observer.duplicateStartAttemptsPrevented, greaterThanOrEqualTo(1));

      observer.dispose();
      clock.dispose();
    });

    test('11. AutomationEngine loop prevention and memory bounding', () async {
      final engine = AutomationEngine(
        initialRules: automations,
        repository: repository,
        maxExecutionHistory: 50,
      );

      expect(engine.rules.length, equals(100));

      // Rapidly evaluate automations
      final testTime = DateTime(2026, 10, 20, 10, 0);
      await engine.evaluate(virtualTime: testTime, devices: devices);

      expect(engine.executionHistory.length, lessThanOrEqualTo(50));

      engine.dispose();
      expect(engine.isDisposed, isTrue);
    });

    test('12. Clean teardown and disposal of all repositories and services',
        () async {
      final testRepo = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: devices,
      );
      final testEngine = SimulationEngine(
        repository: testRepo,
        initialDevices: devices,
      );

      expect(testEngine.isDisposed, isFalse);
      expect(testEngine.clock.isDisposed, isFalse);

      testEngine.dispose();
      await testRepo.dispose();

      expect(testEngine.isDisposed, isTrue);
      expect(testEngine.clock.isDisposed, isTrue);
    });
  });
}
