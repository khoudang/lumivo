import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/repositories/device_repository.dart';
import '../../../services/storage/home_persistence_manager.dart';

class ScenesNotifier extends StateNotifier<List<Scene>> {
  ScenesNotifier([
    List<Scene>? initialScenes,
    this._persistenceManager,
  ]) : super(initialScenes ?? List.of(HomePersistenceManager.defaultScenes));

  final HomePersistenceManager? _persistenceManager;

  void addScene(Scene scene) {
    final index = state.indexWhere((s) => s.id == scene.id);
    if (index >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) scene else state[i],
      ];
    } else {
      state = [...state, scene];
    }
    _persist();
  }

  void deleteScene(String id) {
    state = state.where((s) => s.id != id).toList();
    _persist();
  }

  void updateScene(Scene scene) {
    state = [
      for (final s in state)
        if (s.id == scene.id) scene else s,
    ];
    _persist();
  }

  void setScenes(List<Scene> scenes) {
    state = List.of(scenes);
    _persist();
  }

  Future<void> executeScene(Scene scene, DeviceRepository repo) async {
    for (var i = 0; i < scene.actions.length; i++) {
      final action = scene.actions[i];
      await repo.sendCommand(
        DeviceCommand(
          requestId:
              'scene-${scene.id}-${DateTime.now().microsecondsSinceEpoch}-$i',
          deviceId: action.deviceId,
          type: action.commandType,
          value: action.value,
        ),
      );
    }
  }

  void _persist() {
    _persistenceManager?.saveScenes(state);
  }
}

final scenesProvider =
    StateNotifierProvider<ScenesNotifier, List<Scene>>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final initial =
      persistence.cachedState?.scenes ?? HomePersistenceManager.defaultScenes;
  return ScenesNotifier(initial, persistence);
});
