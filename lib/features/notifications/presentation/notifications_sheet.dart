import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/in_app_notification.dart';
import '../../../core/theme/app_theme.dart';
import '../state/notifications_providers.dart';

class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Header
              Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '$unreadCount New',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (unreadCount > 0)
                    TextButton(
                      key: const Key('mark_all_read_button'),
                      onPressed: () {
                        ref
                            .read(notificationsProvider.notifier)
                            .markAllAsRead();
                      },
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Notifications list
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 48,
                              color: AppColors.muted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No notifications',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          return _buildNotificationCard(context, ref, notif);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    InAppNotification notif,
  ) {
    final (tint, icon) = _severityMeta(notif.severity);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(notificationsProvider.notifier).dismissNotification(notif.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead
              ? AppColors.surfaceElevated
              : AppColors.surfaceElevated.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notif.isRead
                ? AppColors.surfaceBorder
                : AppColors.primary.withValues(alpha: 0.4),
            width: notif.isRead ? 1.0 : 1.3,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notif.timestamp),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: AppColors.muted,
              onPressed: () {
                ref
                    .read(notificationsProvider.notifier)
                    .dismissNotification(notif.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _severityMeta(ActivitySeverity severity) {
    switch (severity) {
      case ActivitySeverity.info:
        return (AppColors.cyan, Icons.info_outline_rounded);
      case ActivitySeverity.success:
        return (AppColors.green, Icons.check_circle_outline_rounded);
      case ActivitySeverity.warning:
        return (AppColors.warning, Icons.warning_amber_rounded);
      case ActivitySeverity.alert:
        return (AppColors.danger, Icons.error_outline_rounded);
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
