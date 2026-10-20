import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/in_app_notification.dart';

final List<InAppNotification> defaultNotifications = [
  InAppNotification(
    id: 'notif-1',
    title: 'High Temperature Detected',
    body: 'Balcony sensor reported 32.4°C. Threshold is 30.0°C.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    isRead: false,
    severity: ActivitySeverity.alert,
  ),
  InAppNotification(
    id: 'notif-2',
    title: 'Automation Executed',
    body: 'Morning Routine triggered successfully at 07:30.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
    isRead: false,
    severity: ActivitySeverity.success,
  ),
  InAppNotification(
    id: 'notif-3',
    title: 'Bedroom Fan Offline',
    body: 'Smart device disconnected from MQTT bridge.',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: true,
    severity: ActivitySeverity.warning,
  ),
];

class NotificationsNotifier extends StateNotifier<List<InAppNotification>> {
  NotificationsNotifier([List<InAppNotification>? initial])
      : super(initial ?? defaultNotifications);

  void markAllAsRead() {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
  }

  void dismissNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void addNotification(InAppNotification notification) {
    state = [notification, ...state];
  }

  void reset() {
    state = defaultNotifications;
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<InAppNotification>>(
        (ref) {
  return NotificationsNotifier();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.where((n) => !n.isRead).length;
});
