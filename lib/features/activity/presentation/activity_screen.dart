import 'package:flutter/material.dart';
import '../../../app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/theme/app_theme.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _activeFilter = 'All';

  Future<void> _confirmClearHistory(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.clearHistory),
        content: Text(l10n.confirmClearHistoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_clear_history_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.clearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(activityProvider.notifier).clearEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.historyCleared),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final currentHome = ref.watch(currentHomeProvider);
    final allEvents = ref.watch(activityProvider);
    final homeEvents =
        allEvents.where((e) => e.homeId == null || e.homeId == currentHome.id);

    final filtered = homeEvents.where((e) {
      if (_activeFilter == 'All') return true;
      if (_activeFilter == 'Automations') {
        return e.source == 'automation';
      }
      if (_activeFilter == 'Manual') {
        return e.source == 'manual';
      }
      if (_activeFilter == 'Alerts') {
        return e.severity == ActivitySeverity.alert ||
            e.severity == ActivitySeverity.warning;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AUDIT & LOGS',
                              style: TextStyle(
                                letterSpacing: 1.5,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.activityTimeline,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('clear_history_button'),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        color: AppColors.muted,
                        tooltip: l10n.clearHistory,
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => _confirmClearHistory(l10n),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Automations', 'Manual', 'Alerts']
                          .map((filter) {
                        final isSelected = _activeFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.22),
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceBorder,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _activeFilter = filter);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off_rounded,
                              size: 48, color: AppColors.muted),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noActivity,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildTimelineItem(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(ActivityEvent item) {
    final (tint, icon) = _severityMeta(item.severity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.severity == ActivitySeverity.alert
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tint.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatRelativeTime(item.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.source.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    if (item.roomId != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.roomId!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cyan,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _severityMeta(ActivitySeverity severity) {
    switch (severity) {
      case ActivitySeverity.info:
        return (AppColors.blue, Icons.info_outline_rounded);
      case ActivitySeverity.success:
        return (AppColors.green, Icons.check_circle_outline_rounded);
      case ActivitySeverity.warning:
        return (AppColors.warning, Icons.warning_amber_rounded);
      case ActivitySeverity.alert:
        return (AppColors.danger, Icons.error_outline_rounded);
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
