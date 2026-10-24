import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/energy_sample.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/automation/state/scenes_notifier.dart';
import 'package:lumivo/features/dashboard/widgets/device_card.dart';
import 'package:lumivo/features/energy/state/energy_notifier.dart';
import 'package:lumivo/features/home/state/homes_notifier.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 3 Comprehensive Acceptance Flows Test Suite', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistence;
    late MockDeviceRepository repository;
    late HomesNotifier homesNotifier;
    late ScenesNotifier scenesNotifier;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistence = HomePersistenceManager(storage: storage);
      await persistence.resetDemoData();

      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: HomePersistenceManager.allDemoDevices,
        persistenceManager: persistence,
      );

      homesNotifier = HomesNotifier(
        HomesState(
          homes: List.of(HomePersistenceManager.defaultHomes),
          currentHomeId: 'home-default',
        ),
        persistence,
      );

      scenesNotifier = ScenesNotifier(
        List.of(HomePersistenceManager.defaultScenes),
        persistence,
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    // =========================================================================
    // Flow A: Home Isolation
    // =========================================================================
    testWidgets(
        'Flow A: Home Isolation — devices and rooms in Home 1 hidden in Home 2',
        (tester) async {
      // 1. Verify Home 1 (Downtown Penthouse) device isolation
      final home1Devices = repository.getDevicesForHome('home-default');
      expect(home1Devices.length, 7);
      for (final device in home1Devices) {
        expect(device.homeId, 'home-default');
      }
      expect(home1Devices.any((d) => d.id == 'device-villa-light'), isFalse);
      expect(home1Devices.any((d) => d.id == 'device-villa-socket'), isFalse);

      // 2. Verify Home 2 (Suburban Villa) device isolation
      final home2Devices = repository.getDevicesForHome('home-suburban');
      expect(home2Devices.length, 2);
      for (final device in home2Devices) {
        expect(device.homeId, 'home-suburban');
      }
      expect(home2Devices.any((d) => d.id == 'device-bulb-1'), isFalse);
      expect(home2Devices.any((d) => d.id == 'device-ac-1'), isFalse);

      // 3. Switch home via HomesNotifier
      expect(homesNotifier.state.currentHomeId, 'home-default');
      expect(homesNotifier.state.currentHome?.name, 'Downtown Penthouse');
      expect(homesNotifier.state.currentHome?.tariffRate, 0.16);

      homesNotifier.switchHome('home-suburban');
      expect(homesNotifier.state.currentHomeId, 'home-suburban');
      expect(homesNotifier.state.currentHome?.name, 'Suburban Villa');
      expect(homesNotifier.state.currentHome?.tariffRate, 0.14);

      // 4. Widget verification: UI rendering active home devices
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final d in repository.getDevicesForHome('home-default'))
                  Text(d.name),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Smart Light'), findsOneWidget);
      expect(find.text('Garden Spotlight'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final d in repository.getDevicesForHome('home-suburban'))
                  Text(d.name),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Garden Spotlight'), findsOneWidget);
      expect(find.text('Smart Light'), findsNothing);
    });

    // =========================================================================
    // Flow B: Favorite Reorder & Persist
    // =========================================================================
    test(
        'Flow B: Favorite Reorder & Persist — reordering updates order and persists',
        () async {
      // Reorder favorites: Bedroom AC first, Smart Fan second, Smart Light third
      await repository.reorderFavorites([
        'device-ac-1',
        'device-fan-1',
        'device-bulb-1',
      ]);

      final ac = repository.devices.firstWhere((d) => d.id == 'device-ac-1');
      expect(ac.isFavorite, isTrue);
      expect(ac.favoriteOrder, 0);

      final fan = repository.devices.firstWhere((d) => d.id == 'device-fan-1');
      expect(fan.isFavorite, isTrue);
      expect(fan.favoriteOrder, 1);

      final bulb =
          repository.devices.firstWhere((d) => d.id == 'device-bulb-1');
      expect(bulb.isFavorite, isTrue);
      expect(bulb.favoriteOrder, 2);

      // Verify updateDeviceSettings
      await repository.updateDeviceSettings(
        'device-ac-1',
        name: 'Inverter Eco AC',
        customIcon: 'ac_unit_rounded',
        roomId: 'Living Room',
      );
      final updatedAc =
          repository.devices.firstWhere((d) => d.id == 'device-ac-1');
      expect(updatedAc.name, 'Inverter Eco AC');
      expect(updatedAc.customIcon, 'ac_unit_rounded');
      expect(updatedAc.roomId, 'Living Room');

      // Verify persistent storage reloads updated order and settings
      final persisted = await persistence.loadHomeState();
      final persistedAc =
          persisted.devices.firstWhere((d) => d.id == 'device-ac-1');
      expect(persistedAc.name, 'Inverter Eco AC');
      expect(persistedAc.isFavorite, isTrue);
      expect(persistedAc.favoriteOrder, 0);

      final persistedFan =
          persisted.devices.firstWhere((d) => d.id == 'device-fan-1');
      expect(persistedFan.favoriteOrder, 1);
    });

    // =========================================================================
    // Flow C: Multi-Device Scene Execution
    // =========================================================================
    test(
        'Flow C: Multi-Device Scene Execution — triggers commands across multiple devices',
        () async {
      // Create multi-device scene: turn off bulb, lock front door, set AC to 20°C
      const customScene = Scene(
        id: 'scene-custom-test',
        name: 'Eco Sleep Mode',
        actions: [
          DeviceAction(
            deviceId: 'device-bulb-1',
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
          DeviceAction(
            deviceId: 'device-lock-1',
            commandType: DeviceCommandType.setLock,
            value: true,
          ),
          DeviceAction(
            deviceId: 'device-ac-1',
            commandType: DeviceCommandType.setTargetTemperature,
            value: 20.0,
          ),
        ],
      );

      // Ensure initial states are different
      await repository.sendCommand(
        const DeviceCommand(
          requestId: 'init-1',
          deviceId: 'device-bulb-1',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      await repository.sendCommand(
        const DeviceCommand(
          requestId: 'init-2',
          deviceId: 'device-lock-1',
          type: DeviceCommandType.setLock,
          value: false,
        ),
      );

      expect(
        repository.devices.firstWhere((d) => d.id == 'device-bulb-1').isOn,
        isTrue,
      );
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-lock-1').isLocked,
        isFalse,
      );

      // Execute scene
      await scenesNotifier.executeScene(customScene, repository);

      // Verify all target devices changed state
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-bulb-1').isOn,
        isFalse,
      );
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-lock-1').isLocked,
        isTrue,
      );
      expect(
        repository.devices
            .firstWhere((d) => d.id == 'device-ac-1')
            .targetTemperature,
        20.0,
      );

      // Other devices remained untouched
      expect(
        repository.devices.firstWhere((d) => d.id == 'device-fan-1').isOn,
        isFalse,
      );
    });

    // =========================================================================
    // Flow D: Cascade Deletion
    // =========================================================================
    test(
        'Flow D: Cascade Deletion — removing device prunes automations and scenes without dangling refs',
        () async {
      // 1. Initial verification: device-ac-1 is present in scenes and automations
      final initialState = await persistence.loadHomeState();
      final hasAcInScenes = initialState.scenes
          .any((s) => s.actions.any((a) => a.deviceId == 'device-ac-1'));
      expect(hasAcInScenes, isTrue);

      final hasAcInRules = initialState.automations
          .any((r) => r.actions.any((a) => a.deviceId == 'device-ac-1'));
      expect(hasAcInRules, isTrue);

      // 2. Cascade delete device-ac-1
      await repository.removeDeviceWithCascade('device-ac-1');

      // In-memory removal
      expect(repository.devices.any((d) => d.id == 'device-ac-1'), isFalse);

      // Persistence verification
      final stateAfterAc = await persistence.loadHomeState();
      expect(stateAfterAc.devices.any((d) => d.id == 'device-ac-1'), isFalse);

      // Pruned from all scenes
      for (final s in stateAfterAc.scenes) {
        expect(s.actions.any((a) => a.deviceId == 'device-ac-1'), isFalse);
      }

      // Pruned from automations
      for (final r in stateAfterAc.automations) {
        expect(r.actions.any((a) => a.deviceId == 'device-ac-1'), isFalse);
      }

      // Cascade event logged
      expect(
        stateAfterAc.activityEvents.any(
          (e) => e.deviceId == 'device-ac-1' && e.title.contains('Cascade'),
        ),
        isTrue,
      );

      // 3. Cascade delete sensor device: disables referencing rule
      await repository.removeDeviceWithCascade('device-sensor-1');
      final stateAfterSensor = await persistence.loadHomeState();
      for (final r in stateAfterSensor.automations) {
        expect(r.sensorDeviceId, isNot('device-sensor-1'));
      }

      // 4. Cascade delete entire Home (Suburban Villa)
      await repository.deleteHomeWithCascade('home-suburban');
      expect(
        repository.devices.any((d) => d.homeId == 'home-suburban'),
        isFalse,
      );

      final stateAfterHome = await persistence.loadHomeState();
      expect(
        stateAfterHome.devices.any((d) => d.homeId == 'home-suburban'),
        isFalse,
      );
      expect(
        stateAfterHome.rooms.any((r) => r.homeId == 'home-suburban'),
        isFalse,
      );
      expect(
        stateAfterHome.scenes.any((s) => s.homeId == 'home-suburban'),
        isFalse,
      );
      expect(
        stateAfterHome.automations.any((a) => a.homeId == 'home-suburban'),
        isFalse,
      );
      expect(
        stateAfterHome.homes.any((h) => h.id == 'home-suburban'),
        isFalse,
      );
    });

    // =========================================================================
    // Flow E: Energy Math Verification
    // =========================================================================
    test(
        'Flow E: Energy Math Verification — verify Wattage x hours and tariff estimation',
        () {
      // 1. Math formula test: AC 850W running for 2 hours
      // Energy = (850W * 2h) / 1000 = 1.700 kWh
      // Cost at $0.16/kWh = 1.7 * 0.16 = $0.272
      final now = DateTime.now();
      final sample1 = EnergySample(
        timestamp: now.subtract(const Duration(hours: 2)),
        powerWatts: 850.0,
        energyKWh: 0.85,
        deviceId: 'device-ac-1',
      );
      final sample2 = EnergySample(
        timestamp: now.subtract(const Duration(hours: 1)),
        powerWatts: 850.0,
        energyKWh: 0.85,
        deviceId: 'device-ac-1',
      );
      final sample3 = EnergySample(
        timestamp: now,
        powerWatts: 100.0,
        energyKWh: 0.10,
        deviceId: 'device-bulb-1',
      );

      // Compute summary at tariff 0.16
      final summary = EnergySummaryNotifier.computeSummary(
        period: EnergyPeriod.day,
        tariffRate: 0.16,
        currency: 'USD',
        allSamples: [sample1, sample2, sample3],
        referenceTime: now,
      );

      // totalKWh = 0.85 + 0.85 + 0.10 = 1.8000 kWh
      expect(summary.totalKWh, 1.8);
      // totalCost = 1.8 * 0.16 = 0.288
      expect(summary.totalCost, 0.288);
      // peakWatts = 850.0
      expect(summary.peakWatts, 850.0);
      // averageWatts = (850 + 850 + 100) / 3 = 600.0
      expect(summary.averageWatts, 600.0);
      // deviceBreakdown
      expect(summary.deviceBreakdown['device-ac-1'], 1.7);
      expect(summary.deviceBreakdown['device-bulb-1'], 0.10);

      // 2. Change tariff rate to Suburban Villa tariff (0.14)
      final suburbanSummary = EnergySummaryNotifier.computeSummary(
        period: EnergyPeriod.day,
        tariffRate: 0.14,
        currency: 'USD',
        allSamples: [sample1, sample2, sample3],
        referenceTime: now,
      );
      // totalCost = 1.8 * 0.14 = 0.252
      expect(suburbanSummary.totalCost, 0.252);

      // 3. StateNotifier dynamic updates
      final energyNotifier = EnergySummaryNotifier(
        period: EnergyPeriod.day,
        tariffRate: 0.16,
        initialSamples: [sample1, sample2, sample3],
      );

      expect(energyNotifier.state.totalCost, 0.288);
      energyNotifier.setTariffRate(0.14);
      expect(energyNotifier.state.totalCost, 0.252);

      energyNotifier.addSample(
        EnergySample(
          timestamp: now,
          powerWatts: 50.0,
          energyKWh: 0.05,
          deviceId: 'device-fan-1',
        ),
      );
      // New totalKWh = 1.8 + 0.05 = 1.85
      expect(energyNotifier.state.totalKWh, 1.85);
      // New totalCost = 1.85 * 0.14 = 0.259
      expect(energyNotifier.state.totalCost, 0.259);
    });

    // =========================================================================
    // Flow F: Schema Migration
    // =========================================================================
    test(
        'Flow F: Schema Migration — loading V2 JSON returns V3 state with default home',
        () async {
      final v2Map = {
        'schemaVersion': 2,
        'devices': [
          {
            'id': 'legacy-ac',
            'name': 'Legacy AC Unit',
            'roomId': 'Living Room',
            'type': 'ac',
            'isOn': true,
            'targetTemperature': 23.0,
          }
        ],
      };

      // Clear existing V3 state so it falls back to V2 key
      await storage.clear();
      await storage.setString(
        HomePersistenceManager.v2StorageKey,
        jsonEncode(v2Map),
      );

      final state = await persistence.loadHomeState();

      expect(state.schemaVersion, greaterThanOrEqualTo(3));
      expect(state.homes.isNotEmpty, isTrue);
      expect(state.homes.any((h) => h.id == 'home-default'), isTrue);
      expect(state.currentHomeId, 'home-default');

      // Tagged with home-default
      final dev = state.devices.firstWhere((d) => d.id == 'legacy-ac');
      expect(dev.homeId, 'home-default');
      expect(dev.targetTemperature, 23.0);

      // Default profile and energy samples attached
      expect(state.userProfile.name, 'Alex Mercer');
      expect(state.energySamples.isNotEmpty, isTrue);
    });

    // =========================================================================
    // Flow G: Reset Demo Data
    // =========================================================================
    test(
        'Flow G: Reset Demo Data — triggers full reset and restores rich multi-home demo data',
        () async {
      // Modify repository and persistence
      repository.addDevice(
        const SmartDevice(
          id: 'temp-x',
          name: 'Temp X',
          roomId: 'Living Room',
          type: DeviceType.fan,
          isOn: true,
        ),
      );
      await persistence.saveHomes([
        const Home(id: 'home-custom', name: 'Custom Villa'),
      ]);

      // Trigger full reset
      final demoState = await persistence.resetDemoData();
      repository.resetToDemo();

      expect(demoState.schemaVersion, greaterThanOrEqualTo(3));
      expect(demoState.homes.length, 2);
      expect(demoState.devices.length, 9);
      expect(
        demoState.devices.where((d) => d.homeId == 'home-default').length,
        7,
      );
      expect(
        demoState.devices.where((d) => d.homeId == 'home-suburban').length,
        2,
      );
      expect(demoState.userProfile.name, 'Alex Mercer');
      expect(demoState.energySamples.length, 24);
      expect(demoState.scenes.length, greaterThanOrEqualTo(5));
      expect(demoState.automations.length, greaterThanOrEqualTo(4));
    });

    // =========================================================================
    // Flow H: Empty/Offline UX
    // =========================================================================
    testWidgets(
        'Flow H: Empty/Offline UX — gracefully renders when home empty or device offline',
        (tester) async {
      // Case 1: Offline Device rendering and command rejection
      const offlineBulb = SmartDevice(
        id: 'dev-offline-test',
        name: 'Patio Light',
        roomId: 'Balcony',
        type: DeviceType.light,
        isOn: false,
        connection: DeviceConnection.offline,
      );

      repository.addDevice(offlineBulb);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(device: offlineBulb),
          ),
        ),
      );

      // Offline badge & status rendered
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Disconnected · Balcony'), findsOneWidget);

      // Repository command rejection
      final cmdResult = await repository.sendCommand(
        const DeviceCommand(
          requestId: 'cmd-offline',
          deviceId: 'dev-offline-test',
          type: DeviceCommandType.setPower,
          value: true,
        ),
      );
      expect(cmdResult.status, CommandStatus.failed);
      expect(cmdResult.errorMessage, 'Device offline');

      // Case 2: Empty Home rendering
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final emptyHomeDevices =
                    repository.getDevicesForHome('home-empty-test');
                if (emptyHomeDevices.isEmpty) {
                  return const Center(
                    child: Text('No devices found in this home'),
                  );
                }
                return ListView(
                  children: [
                    for (final dev in emptyHomeDevices) DeviceCard(device: dev),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('No devices found in this home'), findsOneWidget);
    });
  });
}
