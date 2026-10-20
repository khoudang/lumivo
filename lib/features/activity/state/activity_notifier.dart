import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/activity_event.dart';
import '../../../services/storage/home_persistence_manager.dart';

class ActivityNotifier extends StateNotifier<List<ActivityEvent>> {
  ActivityNotifier([
    List<ActivityEvent>? initialEvents,
    this._persistenceManager,
  ]) : super(initialEvents ?? HomePersistenceManager.defaultActivityEvents);

  final HomePersistenceManager? _persistenceManager;

  void addEvent(ActivityEvent event) {
    state = [event, ...state];
    _persist();
  }

  void clearEvents() {
    state = const [];
    _persist();
  }

  void setEvents(List<ActivityEvent> events) {
    state = List.of(events);
    _persist();
  }

  void reset() {
    setEvents(HomePersistenceManager.defaultActivityEvents);
  }

  void _persist() {
    _persistenceManager?.saveActivityEvents(state);
  }
}

final activityProvider =
    StateNotifierProvider<ActivityNotifier, List<ActivityEvent>>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final initial = persistence.cachedState?.activityEvents ??
      HomePersistenceManager.defaultActivityEvents;
  return ActivityNotifier(initial, persistence);
});
