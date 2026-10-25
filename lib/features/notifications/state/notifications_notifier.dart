import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/in_app_notification.dart';
import '../../../services/storage/home_persistence_manager.dart';

class NotificationsNotifier extends StateNotifier<List<InAppNotification>> {
  NotificationsNotifier([
    List<InAppNotification>? initialNotifications,
    this._persistenceManager,
  ]) : super((initialNotifications ??
                HomePersistenceManager.defaultNotifications)
            .take(100)
            .toList());

  final HomePersistenceManager? _persistenceManager;

  void addNotification(InAppNotification notification) {
    state = [notification, ...state].take(100).toList();
    _persist();
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    _persist();
  }

  void markAllAsRead() {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    _persist();
  }

  void dismissNotification(String id) {
    state = state.where((n) => n.id != id).toList();
    _persist();
  }

  void clearAll() {
    state = const [];
    _persist();
  }

  void reset() {
    setNotifications(HomePersistenceManager.defaultNotifications);
  }

  void setNotifications(List<InAppNotification> notifications) {
    state = notifications.take(100).toList();
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

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.where((n) => !n.isRead).length;
});
