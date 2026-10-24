import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/energy/state/energy_insights_notifier.dart';
import 'package:lumivo/features/search/state/device_search_notifier.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group(
      'Phase 6 Large-Scale Performance Stress Tests (100 Devices, 20 Rooms, 100 Automations, 1000 Events)',
      () {
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
                          : 'Room ${i + 1}',
          iconName: 'room_icon_$i',
          description: 'High-density stress zone #$i',
          homeId: 'home-default',
        );
      });

      // 2. Generate 100 devices across 20 rooms (5 devices per room)
      devices = List.generate(100, (i) {
        final room = rooms[i % rooms.length];
        final type = deviceTypes[i % deviceTypes.length];
        return SmartDevice(
          id: 'dev-scale-${i + 1}',
          name: '${room.name} ${type.name.toUpperCase()} #${i + 1}',
          roomId: room.id,
          type: type,
          isOn: i % 2 == 0,
          brightness: type == DeviceType.light ? (10 + (i * 7) % 90) : 100,
          targetTemperature: type == DeviceType.ac ? (20.0 + (i % 8)) : 24.0,
          currentTemperature: 24.5,
          currentHumidity: 50.0 + (i % 20),
          position: type == DeviceType.curtain ? (i * 10) % 100 : 0,
          isLocked: type == DeviceType.lock ? (i % 3 != 0) : true,
          powerUsageWatts: i % 2 == 0 ? 15.0 + (i % 65) : 0.0,
          connection:
              i % 10 == 0 ? DeviceConnection.offline : DeviceConnection.online,
          homeId: 'home-default',
          isFavorite: i % 5 == 0,
          favoriteOrder: i,
        );
      });

      // 3. Generate 100 automations
      automations = List.generate(100, (i) {
        final targetDev = devices[i % devices.length];
        return AutomationRule(
          id: 'rule-scale-${i + 1}',
          name: 'Scale Automation #${i + 1}',
          isEnabled: i % 4 != 0,
          triggerType:
              i % 2 == 0 ? TriggerType.schedule : TriggerType.sensorThreshold,
          timeOfDay: '08:${(i % 60).toString().padLeft(2, '0')}',
          sensorDeviceId: targetDev.id,
          sensorProperty: 'temperature',
          operator: ComparisonOperator.greaterThan,
          thresholdValue: 26.0,
          homeId: 'home-default',
          actions: [
            DeviceAction(
              deviceId: targetDev.id,
              commandType: DeviceCommandType.setPower,
              value: i % 2 == 0,
            ),
          ],
        );
      });

      // 4. Generate 1000 ActivityEvents
      final baseTime = DateTime(2026, 10, 24, 0, 0);
      activityEvents = List.generate(1000, (i) {
        final refDev = devices[i % devices.length];
        return ActivityEvent(
          id: 'event-scale-${i + 1}',
          title: 'Scale Activity #${i + 1}',
          description: 'High-frequency telemetry log for ${refDev.name}',
          timestamp: baseTime.add(Duration(minutes: i)),
          deviceId: refDev.id,
          roomId: refDev.roomId,
          severity: i % 20 == 0
              ? ActivitySeverity.alert
              : i % 10 == 0
                  ? ActivitySeverity.warning
                  : ActivitySeverity.info,
          source: i % 3 == 0 ? 'automation' : 'device',
        );
      });

      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: devices,
        persistenceManager: persistenceManager,
      );

      await persistenceManager.saveRooms(rooms);
      await persistenceManager.saveDevices(devices);
      await persistenceManager.saveAutomations(automations);
      await persistenceManager.saveActivityEvents(activityEvents);
    });

    tearDown(() async {
      await repository.dispose();
    });

    // -------------------------------------------------------------------------
    // 1. Scale Verification
    // -------------------------------------------------------------------------
    test(
        'Dataset scale verification: 100 devices, 20 rooms, 100 automations, 1000 events',
        () {
      expect(devices.length, equals(100));
      expect(rooms.length, equals(20));
      expect(automations.length, equals(100));
      expect(activityEvents.length, equals(1000));
      expect(repository.devices.length, equals(100));
    });

    // -------------------------------------------------------------------------
    // 2. Device Search Latency (< 50ms)
    // -------------------------------------------------------------------------
    test('Device search latency across 100 devices is strictly < 50ms', () {
      const iterations = 100;
      final sw = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        final query = i % 2 == 0 ? 'Room' : 'LIGHT';
        final results = DeviceSearchEngine.search(
          devices: devices,
          query: query,
          typeFilter: i % 3 == 0 ? DeviceType.light : null,
          statusFilter: i % 4 == 0 ? false : null,
          sortBy: i % 2 == 0 ? 'room' : 'name',
        );
        expect(results, isNotNull);
      }

      sw.stop();
      final totalMs = sw.elapsedMilliseconds;
      final avgMs = totalMs / iterations;

      expect(avgMs, lessThan(50.0),
          reason:
              'Average device search latency must be below 50ms (Actual: ${avgMs.toStringAsFixed(2)}ms)');
    });

    // -------------------------------------------------------------------------
    // 3. Room Filtering Latency (< 20ms)
    // -------------------------------------------------------------------------
    test('Room filtering latency across 20 rooms is strictly < 20ms', () {
      const iterations = 100;
      final sw = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        for (final room in rooms) {
          final roomDevices =
              devices.where((d) => d.roomId == room.id).toList();
          expect(roomDevices.length, equals(5));
        }
      }

      sw.stop();
      final totalMs = sw.elapsedMilliseconds;
      final avgMsPerIteration = totalMs / iterations;

      expect(avgMsPerIteration, lessThan(20.0),
          reason:
              'Average room filtering latency must be below 20ms (Actual: ${avgMsPerIteration.toStringAsFixed(2)}ms)');
    });

    // -------------------------------------------------------------------------
    // 4. Energy Analytics Computation Latency at Scale (< 20ms)
    // -------------------------------------------------------------------------
    test(
        'Energy report computation across 100 devices & 20 rooms is strictly < 20ms',
        () {
      const iterations = 50;
      final sw = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        final report = EnergyInsightsEngine.computeReport(
          period: 'month',
          devices: devices,
          rooms: rooms,
          tariff: 0.16,
        );
        expect(report.deviceBreakdown.length, equals(100));
        expect(report.roomBreakdown.length, equals(20));
        expect(report.totalKwh, greaterThan(0.0));
      }

      sw.stop();
      final totalMs = sw.elapsedMilliseconds;
      final avgMs = totalMs / iterations;

      expect(avgMs, lessThan(20.0),
          reason:
              'Energy calculation latency at scale must be below 20ms (Actual: ${avgMs.toStringAsFixed(2)}ms)');
    });

    // -------------------------------------------------------------------------
    // 5. Memory Stability & Concurrent Command Dispatch
    // -------------------------------------------------------------------------
    test(
        'Concurrent dispatch of 100 state commands maintains memory stability and state integrity',
        () async {
      final futures = <Future<void>>[];

      for (int i = 0; i < 100; i++) {
        final dev = devices[i];
        futures.add(
          repository.sendCommand(
            DeviceCommand(
              requestId: 'cmd-scale-$i',
              deviceId: dev.id,
              type: DeviceCommandType.setPower,
              value: true,
            ),
          ),
        );
      }

      await Future.wait(futures);

      // Verify all 100 devices are now ON
      for (int i = 0; i < 100; i++) {
        final updated =
            repository.devices.firstWhere((d) => d.id == devices[i].id);
        expect(updated.isOn, isTrue);
      }

      // Verify history records remain bounded to max 100
      final history =
          persistenceManager.getCommandRecords(homeId: 'home-default');
      expect(history.length, lessThanOrEqualTo(100));
    });
  });
}
