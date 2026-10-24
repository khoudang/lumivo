import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/theme/app_theme.dart';
import '../state/automation_providers.dart';

class AutomationHistorySheet extends ConsumerStatefulWidget {
  const AutomationHistorySheet({super.key});

  static Future<T?> show<T>(BuildContext context) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AutomationHistorySheet(),
    );
  }

  @override
  ConsumerState<AutomationHistorySheet> createState() =>
      _AutomationHistorySheetState();
}

class _AutomationHistorySheetState
    extends ConsumerState<AutomationHistorySheet> {
  AutomationExecutionStatus? _filterStatus;

  Color _getStatusColor(AutomationExecutionStatus status) {
    switch (status) {
      case AutomationExecutionStatus.executed:
        return AppColors.green;
      case AutomationExecutionStatus.skipped:
        return AppColors.warning;
      case AutomationExecutionStatus.failed:
        return AppColors.danger;
      case AutomationExecutionStatus.loopPrevented:
        return const Color(0xFFB388FF); // Vibrant Purple
    }
  }

  IconData _getStatusIcon(AutomationExecutionStatus status) {
    switch (status) {
      case AutomationExecutionStatus.executed:
        return Icons.check_circle_rounded;
      case AutomationExecutionStatus.skipped:
        return Icons.next_plan_rounded;
      case AutomationExecutionStatus.failed:
        return Icons.error_rounded;
      case AutomationExecutionStatus.loopPrevented:
        return Icons.all_inclusive_rounded;
    }
  }

  String _getStatusLabel(
      AutomationExecutionStatus status, AppLocalizations l10n) {
    switch (status) {
      case AutomationExecutionStatus.executed:
        return 'Executed';
      case AutomationExecutionStatus.skipped:
        return 'Skipped';
      case AutomationExecutionStatus.failed:
        return 'Failed';
      case AutomationExecutionStatus.loopPrevented:
        return 'Loop Prevented';
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations.fromLanguageCode('en');
    final records = ref.watch(automationHistoryProvider);
    final filtered = _filterStatus == null
        ? records
        : records.where((r) => r.status == _filterStatus).toList();

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.executionHistory,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${records.length} records logged',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Filter Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l10n.all),
                      selected: _filterStatus == null,
                      onSelected: (_) => setState(() => _filterStatus = null),
                      selectedColor: AppColors.primary.withValues(alpha: 0.28),
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: _filterStatus == null
                            ? Colors.white
                            : AppColors.muted,
                        fontWeight: _filterStatus == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ...AutomationExecutionStatus.values.map((status) {
                    final isSelected = _filterStatus == status;
                    final color = _getStatusColor(status);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_getStatusLabel(status, l10n)),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _filterStatus = status),
                        selectedColor: color.withValues(alpha: 0.25),
                        backgroundColor: AppColors.surfaceElevated,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.muted,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Records List
            Flexible(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.history_toggle_off_rounded,
                              size: 44,
                              color: AppColors.mutedDark,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noHistory,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = filtered[index];
                        final statusColor = _getStatusColor(record.status);
                        final statusIcon = _getStatusIcon(record.status);
                        final statusLabel =
                            _getStatusLabel(record.status, l10n);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Rule Name & Status Badge & Timestamp
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      record.ruleName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          statusColor.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            statusColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 12,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTimestamp(record.timestamp),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Reason explanation
                              Text(
                                record.reason,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
