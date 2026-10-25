import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/activity_event.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/device_command.dart';
import '../../core/repositories/device_repository.dart';
import '../storage/home_persistence_manager.dart';

/// Abstract interface for managing customizable multi-device scenes.
abstract interface class ScenesService {
  factory ScenesService({
    List<Scene>? initialScenes,
    HomePersistenceManager? persistenceManager,
    void Function(ActivityEvent event)? onActivityEvent,
  }) = DefaultScenesService;

  /// Returns the scenes list, optionally filtered by [homeId].
  List<Scene> getScenes({String? homeId});

  /// Stream emitting the active list of scenes whenever modified.
  Stream<List<Scene>> get scenesStream;

  /// Stream emitting [ActivityEvent] logged when scenes execute.
  Stream<ActivityEvent> get activityStream;

  /// History of emitted scene [ActivityEvent]s.
  List<ActivityEvent> get activityHistory;

  /// Creates a new scene with the specified actions and persists it.
  Future<Scene> createScene(
    String name, {
    String iconName = 'auto_awesome',
    required List<DeviceAction> actions,
    String homeId = 'home-default',
  });

  /// Updates an existing scene by id.
  Future<void> updateScene(Scene scene);

  /// Deletes a scene by [sceneId].
  Future<void> deleteScene(String sceneId);

  /// Sequentially dispatches each [DeviceAction] in [scene] to [repo.sendCommand].
  /// Emits an [ActivityEvent] upon completion.
  Future<void> executeScene(Scene scene, DeviceRepository repo);

  /// Removes all actions targeting [deviceId] across all scenes.
  /// Prevents dangling commands when a device is deleted.
  void pruneDeviceReferences(String deviceId);

  /// Disposes internal streams and resources.
  void dispose();
}

/// Concrete implementation of [ScenesService].
class DefaultScenesService implements ScenesService {
  DefaultScenesService({
    List<Scene>? initialScenes,
    this.persistenceManager,
    this.onActivityEvent,
  }) {
    if (initialScenes != null) {
      _scenes.addAll(initialScenes);
    } else if (persistenceManager != null &&
        persistenceManager!.cachedState != null &&
        persistenceManager!.cachedState!.scenes.isNotEmpty) {
      _scenes.addAll(persistenceManager!.cachedState!.scenes);
    } else {
      _scenes.addAll(HomePersistenceManager.defaultScenes);
    }
  }

  final HomePersistenceManager? persistenceManager;
  final void Function(ActivityEvent event)? onActivityEvent;

  final List<Scene> _scenes = [];
  final List<ActivityEvent> _activityHistory = [];

  final StreamController<List<Scene>> _scenesController =
      StreamController<List<Scene>>.broadcast();
  final StreamController<ActivityEvent> _activityController =
      StreamController<ActivityEvent>.broadcast();

  @override
  Stream<List<Scene>> get scenesStream => _scenesController.stream;

  @override
  Stream<ActivityEvent> get activityStream => _activityController.stream;

  @override
  List<ActivityEvent> get activityHistory =>
      List.unmodifiable(_activityHistory);

  @override
  List<Scene> getScenes({String? homeId}) {
    if (homeId != null) {
      return List.unmodifiable(_scenes.where((s) => s.homeId == homeId));
    }
    return List.unmodifiable(_scenes);
  }

  @override
  Future<Scene> createScene(
    String name, {
    String iconName = 'auto_awesome',
    required List<DeviceAction> actions,
    String homeId = 'home-default',
  }) async {
    final id =
        'scene-${DateTime.now().millisecondsSinceEpoch}-${_scenes.length + 1}';
    final scene = Scene(
      id: id,
      name: name,
      iconName: iconName,
      actions: List.unmodifiable(actions),
      homeId: homeId,
    );

    _scenes.add(scene);
    _emitScenes();
    await _persist();
    return scene;
  }

  @override
  Future<void> updateScene(Scene scene) async {
    final index = _scenes.indexWhere((s) => s.id == scene.id);
    if (index >= 0) {
      _scenes[index] = scene;
      _emitScenes();
      await _persist();
    } else {
      throw ArgumentError('Scene with id "${scene.id}" not found.');
    }
  }

  @override
  Future<void> deleteScene(String sceneId) async {
    final index = _scenes.indexWhere((s) => s.id == sceneId);
    if (index >= 0) {
      _scenes.removeAt(index);
      _emitScenes();
      await _persist();
    }
  }

  @override
  Future<void> executeScene(Scene scene, DeviceRepository repo) async {
    for (var i = 0; i < scene.actions.length; i++) {
      final action = scene.actions[i];
      final command = DeviceCommand(
        requestId:
            'scene-${scene.id}-${DateTime.now().microsecondsSinceEpoch}-$i',
        deviceId: action.deviceId,
        type: action.commandType,
        value: action.value,
      );
      try {
        await repo.sendCommand(command);
      } catch (e) {
        // Safe handling of missing/deleted device or repository error
      }
    }

    final event = ActivityEvent(
      id: 'act-scene-${scene.id}-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Scene: ${scene.name}',
      description: 'Executed ${scene.actions.length} action(s)',
      timestamp: DateTime.now(),
      deviceId: scene.actions.isNotEmpty ? scene.actions.first.deviceId : null,
      severity: ActivitySeverity.info,
      source: 'scene',
    );

    _activityHistory.add(event);
    if (_activityHistory.length > 100) {
      _activityHistory.removeAt(0);
    }
    if (!_activityController.isClosed) {
      _activityController.add(event);
    }
    onActivityEvent?.call(event);

    if (persistenceManager != null) {
      final existingEvents =
          persistenceManager!.cachedState?.activityEvents ?? [];
      await persistenceManager!.saveActivityEvents([...existingEvents, event]);
    }
  }

  @override
  void pruneDeviceReferences(String deviceId) {
    bool modified = false;
    for (int i = 0; i < _scenes.length; i++) {
      final scene = _scenes[i];
      final originalCount = scene.actions.length;
      final updatedActions =
          scene.actions.where((a) => a.deviceId != deviceId).toList();
      if (updatedActions.length != originalCount) {
        _scenes[i] = scene.copyWith(actions: updatedActions);
        modified = true;
      }
    }

    if (modified) {
      _emitScenes();
      _persist();
    }
  }

  void _emitScenes() {
    if (!_scenesController.isClosed) {
      _scenesController.add(List.unmodifiable(_scenes));
    }
  }

  Future<void> _persist() async {
    if (persistenceManager != null) {
      await persistenceManager!.saveScenes(_scenes);
    }
  }

  @override
  void dispose() {
    _scenesController.close();
    _activityController.close();
  }
}

/// Riverpod provider for [ScenesService].
final scenesServiceProvider = Provider<ScenesService>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final service = DefaultScenesService(
    persistenceManager: persistence,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Riverpod stream provider for scenes list.
final scenesListStreamProvider =
    StreamProvider.family<List<Scene>, String?>((ref, homeId) {
  final service = ref.watch(scenesServiceProvider);
  return Stream.value(service.getScenes(homeId: homeId))
      .concatWith(service.scenesStream.map(
    (scenes) => homeId != null
        ? scenes.where((s) => s.homeId == homeId).toList()
        : scenes,
  ));
});

extension _StreamConcatScenes<T> on Stream<T> {
  Stream<T> concatWith(Stream<T> other) async* {
    yield* this;
    yield* other;
  }
}
