import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/home.dart';
import '../../../services/storage/home_persistence_manager.dart';

class HomesState {
  const HomesState({
    required this.homes,
    required this.currentHomeId,
  });

  final List<Home> homes;
  final String currentHomeId;

  Home? get currentHome {
    if (homes.isEmpty) return null;
    return homes.firstWhere(
      (h) => h.id == currentHomeId,
      orElse: () => homes.first,
    );
  }

  HomesState copyWith({
    List<Home>? homes,
    String? currentHomeId,
  }) {
    return HomesState(
      homes: homes ?? this.homes,
      currentHomeId: currentHomeId ?? this.currentHomeId,
    );
  }
}

class HomesNotifier extends StateNotifier<HomesState> {
  HomesNotifier(
    super.initial, [
    this._persistenceManager,
  ]);

  final HomePersistenceManager? _persistenceManager;

  void switchHome(String id) {
    if (!state.homes.any((h) => h.id == id)) return;
    final updatedHomes =
        state.homes.map((h) => h.copyWith(isCurrent: h.id == id)).toList();
    state = state.copyWith(
      currentHomeId: id,
      homes: updatedHomes,
    );
    _persist();
  }

  void addHome(Home home) {
    final index = state.homes.indexWhere((h) => h.id == home.id);
    final List<Home> nextHomes;
    if (index >= 0) {
      nextHomes = [
        for (int i = 0; i < state.homes.length; i++)
          if (i == index) home else state.homes[i],
      ];
    } else {
      nextHomes = [...state.homes, home];
    }
    state = state.copyWith(homes: nextHomes);
    _persist();
  }

  void updateHome(Home home) {
    final nextHomes =
        state.homes.map((h) => h.id == home.id ? home : h).toList();
    state = state.copyWith(homes: nextHomes);
    _persist();
  }

  void deleteHome(String id) {
    final remaining = state.homes.where((h) => h.id != id).toList();
    var nextCurrentId = state.currentHomeId;
    if (state.currentHomeId == id) {
      if (remaining.any((h) => h.id == 'home-default')) {
        nextCurrentId = 'home-default';
      } else if (remaining.isNotEmpty) {
        nextCurrentId = remaining.first.id;
      } else {
        nextCurrentId = 'home-default';
      }
    }
    final updatedHomes = remaining
        .map((h) => h.copyWith(isCurrent: h.id == nextCurrentId))
        .toList();
    state = HomesState(
      homes: updatedHomes,
      currentHomeId: nextCurrentId,
    );
    _persist();
  }

  void setHomes(List<Home> homes, [String? currentHomeId]) {
    final activeId = currentHomeId ?? state.currentHomeId;
    final updatedHomes =
        homes.map((h) => h.copyWith(isCurrent: h.id == activeId)).toList();
    state = HomesState(
      homes: updatedHomes,
      currentHomeId: activeId,
    );
    _persist();
  }

  void _persist() {
    _persistenceManager?.saveHomes(state.homes);
    _persistenceManager?.saveCurrentHomeId(state.currentHomeId);
  }
}

final homesProvider = StateNotifierProvider<HomesNotifier, HomesState>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final cached = persistence.cachedState;
  final initialHomes = (cached != null && cached.homes.isNotEmpty)
      ? cached.homes
      : HomePersistenceManager.defaultHomes;
  final initialCurrentId = cached?.currentHomeId ?? 'home-default';
  return HomesNotifier(
    HomesState(
      homes: initialHomes,
      currentHomeId: initialCurrentId,
    ),
    persistence,
  );
});

final currentHomeProvider = Provider<Home?>((ref) {
  final homesState = ref.watch(homesProvider);
  return homesState.currentHome;
});
