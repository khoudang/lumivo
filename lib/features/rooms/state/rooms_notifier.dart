import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/room.dart';
import '../../../services/storage/home_persistence_manager.dart';

class RoomsNotifier extends StateNotifier<List<Room>> {
  RoomsNotifier([
    List<Room>? initialRooms,
    this._persistenceManager,
  ]) : super(initialRooms ?? List.of(HomePersistenceManager.defaultRooms));

  final HomePersistenceManager? _persistenceManager;

  Future<void> addRoom(Room room) async {
    final index = state.indexWhere((r) => r.id == room.id);
    if (index >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) room else state[i],
      ];
    } else {
      state = [...state, room];
    }
    await _persist();
  }

  Future<void> deleteRoom(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }

  Future<void> updateRoom(Room room) async {
    state = [
      for (final r in state)
        if (r.id == room.id) room else r,
    ];
    await _persist();
  }

  Future<void> setRooms(List<Room> rooms) async {
    state = List.of(rooms);
    await _persist();
  }

  Future<void> _persist() async {
    await _persistenceManager?.saveRooms(state);
  }
}

final roomsProvider = StateNotifierProvider<RoomsNotifier, List<Room>>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final initial =
      persistence.cachedState?.rooms ?? HomePersistenceManager.defaultRooms;
  return RoomsNotifier(initial, persistence);
});
