import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/scenes/scenes_service.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('ScenesService Unit Tests', () {
    late ScenesService service;
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistence;

    setUp(() {
      storage = StorageAdapterImpl();
      persistence = HomePersistenceManager(storage: storage);
      service = ScenesService(persistenceManager: persistence);
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial scenes loaded from defaults', () {
      final scenes = service.getScenes();
      expect(
          scenes.length, equals(HomePersistenceManager.defaultScenes.length));
      expect(scenes.any((s) => s.name == 'Good Morning'), isTrue);
      expect(scenes.any((s) => s.name == 'Night'), isTrue);
    });

    test('getScenes with homeId filter', () async {
      await service.createScene(
        'Beach Scene',
        homeId: 'home-beach',
        actions: const [
          DeviceAction(
            deviceId: 'beach-light',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      final beachScenes = service.getScenes(homeId: 'home-beach');
      expect(beachScenes.length, equals(1));
      expect(beachScenes.first.name, equals('Beach Scene'));

      final defaultScenes = service.getScenes(homeId: 'home-default');
      expect(defaultScenes.every((s) => s.homeId == 'home-default'), isTrue);
    });

    test('createScene adds new scene and emits on stream', () async {
      final emitted = <List<Scene>>[];
      service.scenesStream.listen(emitted.add);

      const actions = [
        DeviceAction(
          deviceId: 'device-bulb-1',
          commandType: DeviceCommandType.setBrightness,
          value: 40,
        ),
      ];

      final created = await service.createScene(
        'Study Mode',
        iconName: 'menu_book',
        actions: actions,
        homeId: 'home-default',
      );

      expect(created.name, equals('Study Mode'));
      expect(created.iconName, equals('menu_book'));
      expect(created.actions.length, equals(1));

      final allScenes = service.getScenes();
      expect(allScenes.any((s) => s.id == created.id), isTrue);

      await pumpEventQueue();
      expect(emitted.isNotEmpty, isTrue);
      expect(emitted.last.any((s) => s.id == created.id), isTrue);
    });

    test('updateScene updates scene metadata and actions', () async {
      final scenes = service.getScenes();
      final target = scenes.first;

      final updated = target.copyWith(
        name: 'Super Morning',
        iconName: 'sunny',
      );

      await service.updateScene(updated);

      final found = service.getScenes().firstWhere((s) => s.id == target.id);
      expect(found.name, equals('Super Morning'));
      expect(found.iconName, equals('sunny'));

      expect(
        () => service.updateScene(const Scene(
          id: 'non-existent',
          name: 'Ghost',
          actions: [],
        )),
        throwsArgumentError,
      );
    });

    test('deleteScene removes scene and persists', () async {
      final initialCount = service.getScenes().length;
      final target = service.getScenes().first;

      await service.deleteScene(target.id);

      final newScenes = service.getScenes();
      expect(newScenes.length, equals(initialCount - 1));
      expect(newScenes.any((s) => s.id == target.id), isFalse);
    });

    test(
        'executeScene dispatches commands sequentially and emits activity event',
        () async {
      final repo = MockDeviceRepository(responseDelay: Duration.zero);
      final emittedEvents = <ActivityEvent>[];
      service.activityStream.listen(emittedEvents.add);

      final scene = Scene(
        id: 'test-exec-scene',
        name: 'Party Time',
        actions: const [
          DeviceAction(
            deviceId: 'device-bulb-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
          DeviceAction(
            deviceId: 'device-bulb-1',
            commandType: DeviceCommandType.setBrightness,
            value: 100,
          ),
        ],
      );

      await service.executeScene(scene, repo);

      expect(service.activityHistory.isNotEmpty, isTrue);
      final lastEvent = service.activityHistory.last;
      expect(lastEvent.title, contains('Party Time'));
      expect(lastEvent.source, equals('scene'));
      expect(lastEvent.description, contains('2 action(s)'));

      await pumpEventQueue();
      expect(emittedEvents.isNotEmpty, isTrue);
      expect(emittedEvents.last.title, contains('Party Time'));
    });

    test(
        'pruneDeviceReferences removes actions targeting deviceId from all scenes',
        () async {
      const targetDeviceId = 'obsolete-device-99';

      await service.createScene(
        'Scene With Target',
        actions: const [
          DeviceAction(
            deviceId: targetDeviceId,
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
          DeviceAction(
            deviceId: 'safe-device-1',
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
        ],
      );

      await service.createScene(
        'Scene Only Target',
        actions: const [
          DeviceAction(
            deviceId: targetDeviceId,
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
        ],
      );

      service.pruneDeviceReferences(targetDeviceId);

      final scenes = service.getScenes();
      final sceneMixed =
          scenes.firstWhere((s) => s.name == 'Scene With Target');
      expect(sceneMixed.actions.length, equals(1));
      expect(sceneMixed.actions.first.deviceId, equals('safe-device-1'));

      final sceneOnly = scenes.firstWhere((s) => s.name == 'Scene Only Target');
      expect(sceneOnly.actions.isEmpty, isTrue);

      // Verify no remaining references anywhere
      for (final s in service.getScenes()) {
        for (final a in s.actions) {
          expect(a.deviceId, isNot(equals(targetDeviceId)));
        }
      }
    });

    test('Scenes are persisted to HomePersistenceManager', () async {
      await service.createScene(
        'Persisted Scene',
        actions: const [],
      );

      final state = await persistence.loadHomeState();
      expect(state.scenes.any((s) => s.name == 'Persisted Scene'), isTrue);
    });
  });
}
