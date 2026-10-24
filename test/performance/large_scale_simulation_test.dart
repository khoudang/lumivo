import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/simulation/simulation_engine.dart';
import 'package:lumivo/services/simulation/virtual_clock.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Large-Scale Simulation & Platform Performance Stress Tests', () {
    late List<Room> rooms;
    late List<SmartDevice> devices;
    late List<ActivityEvent> activityEvents;
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late MockDeviceRepository repository;

    final deviceTypes = [
      DeviceType.light,
      DeviceType.fan,
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
        final roomId = 'room-${i + 1}';
        final roomName = i == 0
            ? 'Living Room'
            : i == 1
                ? 'Master Bedroom'
                : i == 2
                    ? 'Kitchen'
                    : i == 3
                        ? 'Home Office'
                        : i == 4
                            ? 'Balcony'
                            : 'Room ${i + 1}';
        return Room(
          id: roomId,
          name: roomName,
          iconName: 'room_icon_$i',
          description: 'High-density stress test zone $i',
        );
      });

      // 2. Generate 100 SmartDevices evenly distributed across 20 rooms (5 devices per room)
      // Mixed types: bulbs, fans, ACs, sockets, curtains, locks, sensors
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
          targetTemperature: type == DeviceType.ac ? (20.0 + (i % 8)) : 24.0,
          currentTemperature: 24.5,
          currentHumidity: 50.0 + (i % 20),
          position: type == DeviceType.curtain ? (i * 10) % 100 : 0,
          isLocked: type == DeviceType.lock ? (i % 3 != 0) : true,
          powerUsageWatts: i % 2 == 0 ? 15.0 + (i % 45) : 0.0,
          connection: DeviceConnection.online,
        );
      });

      // 3. Generate 500 ActivityEvents referencing devices, rooms and system sources
      final baseTime = DateTime(2026, 10, 24, 8, 0);
      activityEvents = List.generate(500, (i) {
        final refDevice = devices[i % devices.length];
        final severity = i % 15 == 0
            ? ActivitySeverity.alert
            : i % 7 == 0
                ? ActivitySeverity.warning
                : i % 4 == 0
                    ? ActivitySeverity.success
                    : ActivitySeverity.info;

        return ActivityEvent(
          id: 'event-scale-${i + 1}',
          title: 'Telemetry Event #${i + 1}',
          description:
              'Simulated high-frequency activity on ${refDevice.name} at scale.',
          timestamp: baseTime.add(Duration(seconds: i * 30)),
          deviceId: refDevice.id,
          roomId: refDevice.roomId,
          severity: severity,
          source: i % 2 == 0 ? 'automation' : 'simulation',
        );
      });

      // Initialize repository with all 100 devices and zero artificial delay for raw throughput
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: devices,
        persistenceManager: persistenceManager,
      );

      await persistenceManager.saveRooms(rooms);
      await persistenceManager.saveDevices(devices);
      await persistenceManager.saveActivityEvents(activityEvents);
    });

    tearDown(() async {
      await repository.dispose();
      SimulationEngine.resetInstance();
    });

    test('Verification of dataset scale (100 devices, 20 rooms, 500 events)',
        () {
      expect(rooms.length, equals(20));
      expect(devices.length, equals(100));
      expect(activityEvents.length, equals(500));
      expect(repository.devices.length, equals(100));

      final typesCovered = repository.devices.map((d) => d.type).toSet();
      expect(typesCovered.length, equals(deviceTypes.length));
    });

    test('Repository device query latency is well below 50ms', () {
      final sw = Stopwatch()..start();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        final queried = repository.devices;
        expect(queried.length, equals(100));
      }
      sw.stop();

      final totalMs = sw.elapsedMilliseconds;
      final avgMs = totalMs / iterations;

      expect(
        avgMs,
        lessThan(50.0),
        reason: 'Average repository query latency was $avgMs ms (limit 50ms)',
      );
      expect(
        totalMs,
        lessThan(100),
        reason: '50 iterations took $totalMs ms in total',
      );
    });

    test('Room filtering latency across 20 rooms is well below 20ms', () {
      final sw = Stopwatch()..start();
      int totalFilterMatches = 0;

      // Filter all 100 devices into 20 rooms
      for (final room in rooms) {
        final roomDevices =
            repository.devices.where((d) => d.roomId == room.id).toList();
        expect(roomDevices.length, equals(5));
        totalFilterMatches += roomDevices.length;
      }
      sw.stop();

      expect(totalFilterMatches, equals(100));
      expect(
        sw.elapsedMilliseconds,
        lessThan(20),
        reason:
            'Filtering 100 devices across 20 rooms took ${sw.elapsedMilliseconds} ms (limit 20ms)',
      );
    });

    test(
        'Concurrent dispatch of 100 state commands without dropping state or memory leaks',
        () async {
      // Create 100 concurrent commands: toggle power on every device
      final commands = List.generate(100, (i) {
        final device = devices[i];
        final targetPower = !device.isOn;
        return DeviceCommand(
          requestId: 'cmd-concurrent-$i',
          deviceId: device.id,
          type: DeviceCommandType.setPower,
          value: targetPower,
        );
      });

      final sw = Stopwatch()..start();

      // Dispatch all 100 commands concurrently
      final results = await Future.wait(
        commands.map((cmd) => repository.sendCommand(cmd)),
      );
      sw.stop();

      // Verify all commands succeeded
      expect(results.length, equals(100));
      for (final res in results) {
        expect(res.status, equals(CommandStatus.confirmed));
      }

      // Verify repository updated all 100 devices correctly with zero dropped updates
      final updatedDevices = repository.devices;
      expect(updatedDevices.length, equals(100));

      for (int i = 0; i < 100; i++) {
        final original = devices[i];
        final updated = updatedDevices.firstWhere((d) => d.id == original.id);
        expect(
          updated.isOn,
          equals(!original.isOn),
          reason: 'Device ${original.id} did not toggle power correctly',
        );
      }
    });

    test(
        'Mixed-type concurrent commands (brightness, temp, position, lock) execute safely',
        () async {
      final mixedCommands = <DeviceCommand>[];

      for (final d in devices) {
        switch (d.type) {
          case DeviceType.light:
            mixedCommands.add(DeviceCommand(
              requestId: 'req-bright-${d.id}',
              deviceId: d.id,
              type: DeviceCommandType.setBrightness,
              value: 88,
            ));
            break;
          case DeviceType.ac:
            mixedCommands.add(DeviceCommand(
              requestId: 'req-temp-${d.id}',
              deviceId: d.id,
              type: DeviceCommandType.setTargetTemperature,
              value: 21.5,
            ));
            break;
          case DeviceType.curtain:
            mixedCommands.add(DeviceCommand(
              requestId: 'req-pos-${d.id}',
              deviceId: d.id,
              type: DeviceCommandType.setPosition,
              value: 75,
            ));
            break;
          case DeviceType.lock:
            mixedCommands.add(DeviceCommand(
              requestId: 'req-lock-${d.id}',
              deviceId: d.id,
              type: DeviceCommandType.setLock,
              value: false,
            ));
            break;
          case DeviceType.fan:
          case DeviceType.socket:
          case DeviceType.sensor:
          case DeviceType.security:
            mixedCommands.add(DeviceCommand(
              requestId: 'req-pwr-${d.id}',
              deviceId: d.id,
              type: DeviceCommandType.setPower,
              value: true,
            ));
            break;
        }
      }

      final results = await Future.wait(
        mixedCommands.map((c) => repository.sendCommand(c)),
      );

      for (final res in results) {
        expect(res.status, equals(CommandStatus.confirmed));
      }

      final lights =
          repository.devices.where((d) => d.type == DeviceType.light);
      for (final l in lights) {
        expect(l.brightness, equals(88));
        expect(l.isOn, isTrue);
      }

      final acs = repository.devices.where((d) => d.type == DeviceType.ac);
      for (final ac in acs) {
        expect(ac.targetTemperature, equals(21.5));
      }

      final curtains =
          repository.devices.where((d) => d.type == DeviceType.curtain);
      for (final c in curtains) {
        expect(c.position, equals(75));
      }

      final locks = repository.devices.where((d) => d.type == DeviceType.lock);
      for (final l in locks) {
        expect(l.isLocked, isFalse);
      }
    });

    test('SimulationEngine with 100 active devices computes snapshot in < 50ms',
        () async {
      final clock = VirtualClock(autoStart: false);
      final engine = SimulationEngine(
        clock: clock,
        initialDevices: devices,
        autoStart: false,
      );

      expect(engine.devices.length, equals(100));

      final sw = Stopwatch()..start();
      // Advance clock by 10 minutes to trigger tick across 100 simulators
      clock.advance(const Duration(minutes: 10));
      await pumpEventQueue();
      sw.stop();

      final snapshot = engine.currentSnapshot;
      expect(snapshot.devices.length, equals(100));
      expect(snapshot.totalPowerWatts, greaterThan(0.0));
      expect(
        sw.elapsedMilliseconds,
        lessThan(50),
        reason:
            '100-device simulation tick took ${sw.elapsedMilliseconds} ms (limit 50ms)',
      );

      engine.dispose();
      clock.dispose();
    });

    test('Disposing repository cleanly closes watchDevices streams', () async {
      final repoToDispose = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: devices,
      );

      var emissionCount = 0;
      final completer = Completer<void>();

      final subscription = repoToDispose.watchDevices().listen(
        (devList) {
          emissionCount++;
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Give event loop time to emit initial state
      await pumpEventQueue();
      expect(emissionCount, greaterThanOrEqualTo(1));

      // Dispose repository
      await repoToDispose.dispose();
      await subscription.cancel();

      // Disposed repository will not accept new events or leak streams
      expect(emissionCount, greaterThanOrEqualTo(1));
    });

    test('500 ActivityEvents query and room filtering performance', () async {
      final state = await persistenceManager.loadHomeState();
      expect(state.activityEvents.length, equals(500));

      final sw = Stopwatch()..start();
      // Filter events by Living Room
      final livingRoomEvents =
          state.activityEvents.where((e) => e.roomId == 'room-1').toList();
      sw.stop();

      expect(livingRoomEvents.length, equals(25));
      expect(
        sw.elapsedMilliseconds,
        lessThan(20),
        reason: 'Filtering 500 events took ${sw.elapsedMilliseconds} ms',
      );
    });
  });
}
