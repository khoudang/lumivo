import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/storage/home_persistence_manager.dart';
import '../../../services/storage/storage_adapter.dart';

/// Manages whether the first-run welcome onboarding flow has been completed.
///
/// Backed by local persistent storage ([HomePersistenceManager] or [StorageAdapter])
/// to preserve state across app reloads and restarts.
class FirstRunNotifier extends StateNotifier<bool> {
  FirstRunNotifier({
    bool initialValue = false,
    HomePersistenceManager? persistenceManager,
    StorageAdapter? storage,
  })  : _persistenceManager = persistenceManager,
        _storage = storage,
        super(initialValue) {
    _loadFromStorage();
  }

  final HomePersistenceManager? _persistenceManager;
  final StorageAdapter? _storage;

  static const String storageKey = 'lumivo_first_run_completed';

  Future<void> _loadFromStorage() async {
    final storage = _storage;
    final persistenceManager = _persistenceManager;
    if (storage != null) {
      final stored = await storage.getString(storageKey);
      if (stored != null) {
        state = stored == 'true';
      }
    } else if (persistenceManager != null) {
      final isCompleted = await persistenceManager.isFirstRunCompleted();
      state = isCompleted;
    }
  }

  /// Marks first-run welcome flow as completed.
  Future<void> completeFirstRun() async {
    state = true;
    await _persist(true);
  }

  /// Resets first-run status back to uncompleted (useful for testing or demo resets).
  Future<void> resetFirstRun() async {
    state = false;
    await _persist(false);
  }

  /// Explicitly sets the first-run completed status.
  Future<void> setFirstRunCompleted(bool completed) async {
    state = completed;
    await _persist(completed);
  }

  Future<void> _persist(bool value) async {
    final storage = _storage;
    final persistenceManager = _persistenceManager;
    if (storage != null) {
      await storage.setString(storageKey, value.toString());
    }
    if (persistenceManager != null) {
      await persistenceManager.setFirstRunCompleted(value);
    }
  }
}

/// Provider for tracking and mutating whether the first-run welcome flow has finished.
final firstRunCompletedProvider =
    StateNotifierProvider<FirstRunNotifier, bool>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  return FirstRunNotifier(persistenceManager: persistence);
});
