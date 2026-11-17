import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/main.dart' as entry;
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/storage_adapter_factory.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';
import 'package:lumivo/services/simulation/simulation_engine.dart';

void main() {
  test('an absent cache retains repository defaults', () async {
    final persistence = HomePersistenceManager(storage: StorageAdapterImpl());
    final repository = MockDeviceRepository(persistenceManager: persistence);
    addTearDown(repository.dispose);

    expect(persistence.cachedState, isNull);
    expect(repository.devices, hasLength(6));
    expect(repository.getDeviceById('light-1'), isNotNull);
  });

  test('an absent saved state still loads demo seeds', () async {
    final persistence = HomePersistenceManager(storage: StorageAdapterImpl());
    final repository = MockDeviceRepository(persistenceManager: persistence);
    addTearDown(repository.dispose);

    await repository.loadFromPersistence();

    expect(repository.devices, isNotEmpty);
    expect(repository.devices.map((device) => device.id),
        persistence.createDemoState().devices.map((device) => device.id));
  });

  test('explicit empty initialDevices overrides a populated cache', () async {
    final persistence = HomePersistenceManager(storage: StorageAdapterImpl());
    await persistence.saveHomeState(persistence.createDemoState());
    final repository = MockDeviceRepository(
      persistenceManager: persistence,
      initialDevices: const [],
    );
    addTearDown(repository.dispose);

    expect(persistence.cachedState!.devices, isNotEmpty);
    expect(repository.devices, isEmpty);
  });

  test('explicit initialDevices overrides an empty cache', () async {
    final persistence = HomePersistenceManager(storage: StorageAdapterImpl());
    await persistence.saveHomeState(const HomeState(devices: []));
    const initial = SmartDevice(
      id: 'explicit-light',
      name: 'Explicit light',
      roomId: 'Living Room',
      type: DeviceType.light,
      isOn: false,
    );
    final repository = MockDeviceRepository(
      persistenceManager: persistence,
      initialDevices: const [initial],
    );
    addTearDown(repository.dispose);

    expect(repository.devices, [initial]);
    expect(repository.getDeviceById(initial.id), initial);
  });

  test('loadFromPersistence clears devices and emits a saved empty list',
      () async {
    final storage = StorageAdapterImpl();
    final seedManager = HomePersistenceManager(storage: storage);
    await seedManager.saveHomeState(
      seedManager.createDemoState().copyWith(devices: const []),
    );
    final persistence = HomePersistenceManager(storage: storage);
    final repository = MockDeviceRepository(
      persistenceManager: persistence,
      responseDelay: Duration.zero,
    );
    addTearDown(repository.dispose);
    expect(persistence.cachedState, isNull);
    expect(repository.devices, hasLength(6));
    final updates = StreamIterator(repository.watchDevices());
    addTearDown(updates.cancel);
    expect(await updates.moveNext(), isTrue);
    expect(updates.current, hasLength(6));

    await repository.loadFromPersistence();

    expect(repository.devices, isEmpty);
    expect(repository.getDeviceById('light-1'), isNull);
    expect(
        await updates.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(updates.current, isEmpty);
    expect(persistence.cachedState!.devices, isEmpty);
  });

  testWidgets('actual entrypoint preserves a persisted empty device list',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = StorageAdapterImpl();
    final seedManager = HomePersistenceManager(storage: storage);
    await seedManager.saveHomeState(
      seedManager.createDemoState().copyWith(devices: const []),
    );
    StorageAdapterFactory.setMockAdapter(storage);
    addTearDown(() => StorageAdapterFactory.setMockAdapter(null));
    addTearDown(SimulationEngine.resetInstance);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // Establish this test's fake frame clock before runApp's warm-up frame.
    await tester.pump();
    await tester.runAsync(() => Future<void>.sync(entry.main));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    expect(
        container.read(homePersistenceProvider).cachedState!.devices, isEmpty);
    expect(
      await container.read(deviceRepositoryProvider).watchDevices().first,
      isEmpty,
      reason: 'A saved empty home must not resurrect default devices',
    );
  });

  testWidgets('actual entrypoint restores persisted home before providers boot',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = StorageAdapterImpl();
    final seedManager = HomePersistenceManager(storage: storage);
    final seed = seedManager.createDemoState();
    final saved = seed.copyWith(
      devices: const [
        SmartDevice(
          id: 'light-1',
          name: 'Saved reading light',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: false,
          brightness: 31,
        ),
      ],
      userProfile: seed.userProfile.copyWith(language: 'vi', themeMode: 'oled'),
    );
    await seedManager.saveHomeState(saved);
    StorageAdapterFactory.setMockAdapter(storage);
    addTearDown(() => StorageAdapterFactory.setMockAdapter(null));
    addTearDown(SimulationEngine.resetInstance);
    // Establish this test's fake frame clock before runApp's warm-up frame.
    await tester.pump();
    await tester.runAsync(() => Future<void>.sync(entry.main));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    final device =
        (await container.read(deviceRepositoryProvider).watchDevices().first)
            .firstWhere((d) => d.id == 'light-1');
    expect(device.isOn, isFalse,
        reason: 'Boot must not replace saved state with demo devices');
    expect(device.brightness, 31);
    expect(container.read(userProfileProvider).language, 'vi');
    expect(container.read(userProfileProvider).themeMode, 'oled');
    expect(find.text('Chào mừng về nhà ✦'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
