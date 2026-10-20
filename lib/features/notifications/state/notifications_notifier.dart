import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/in_app_notification.dart';
import '../../../services/storage/home_persistence_manager.dart';

class NotificationsNotifier extends StateNotifier<List<InAppNotification>> {
  NotificationsNotifier([
    List<InAppNotification>? initialNotifications,
    this._persistenceManager,
  ]) : super(initialNotifications ??
            HomePersistenceManager.defaultNotifications);

  final HomePersistenceManager? _persistenceManager;

  void addNotification(InAppNotification notification) {
    state = [notification, ...state];
    _persist();
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    _persist();
  }

  void clearAll() {
    state = const [];
    _persist();
  }

  void setNotifications(List<InAppNotification> notifications) {
    state = List.of(notifications);
    _persist();
  }

  void _persist() {
    _persistenceManager?.saveNotifications(state);
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<InAppNotification>>(
        (ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final initial = persistence.cachedState?.notifications ??
      HomePersistenceManager.defaultNotifications;
  return NotificationsNotifier(initial, persistence);
});
