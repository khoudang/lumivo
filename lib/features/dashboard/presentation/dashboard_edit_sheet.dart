import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/dashboard_config.dart';
import '../../../core/theme/app_theme.dart';

class DashboardEditSheet extends ConsumerStatefulWidget {
  const DashboardEditSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DashboardEditSheet(),
    );
  }

  @override
  ConsumerState<DashboardEditSheet> createState() => _DashboardEditSheetState();
}

class _DashboardEditSheetState extends ConsumerState<DashboardEditSheet> {
  late List<DashboardSection> _draftOrder;
  late Map<DashboardSection, bool> _draftVisibility;

  @override
  void initState() {
    super.initState();
    final config = ref.read(dashboardConfigProvider);
    _draftOrder = List.from(config.sectionOrder);
    _draftVisibility = Map.from(config.visibleSections);

    for (final s in DashboardSection.values) {
      if (!_draftOrder.contains(s)) {
        _draftOrder.add(s);
      }
      _draftVisibility.putIfAbsent(s, () => true);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      var adjustedNew = newIndex;
      if (oldIndex < newIndex) {
        adjustedNew -= 1;
      }
      final item = _draftOrder.removeAt(oldIndex);
      _draftOrder.insert(adjustedNew, item);
    });
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _draftOrder.removeAt(index);
        _draftOrder.insert(index - 1, item);
      });
    }
  }

  void _moveDown(int index) {
    if (index < _draftOrder.length - 1) {
      setState(() {
        final item = _draftOrder.removeAt(index);
        _draftOrder.insert(index + 1, item);
      });
    }
  }

  void _save() {
    final current = ref.read(dashboardConfigProvider);
    final updated = current.copyWith(
      sectionOrder: List.from(_draftOrder),
      visibleSections: Map.from(_draftVisibility),
    );
    ref.read(dashboardConfigProvider.notifier).setConfig(updated);

    final l10n = ref.read(appLocalizationsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.dashboardCustomized),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _reset() async {
    final l10n = ref.read(appLocalizationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.resetDashboardLayout),
        content: Text(l10n.resetDashboardConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: Key('confirm_reset_dashboard_layout_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.resetLayout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _applyReset();
    }
  }

  void _applyReset() {
    ref.read(dashboardConfigProvider.notifier).resetToDefaults();
    final config = ref.read(dashboardConfigProvider);
    setState(() {
      _draftOrder = List.from(config.sectionOrder);
      _draftVisibility = Map.from(config.visibleSections);
      for (final s in DashboardSection.values) {
        if (!_draftOrder.contains(s)) {
          _draftOrder.add(s);
        }
        _draftVisibility.putIfAbsent(s, () => true);
      }
    });

    final l10n = ref.read(appLocalizationsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.resetLayout),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getSectionTitle(DashboardSection section, AppLocalizations l10n) {
    switch (section) {
      case DashboardSection.metrics:
        return '${l10n.temperature} & ${l10n.energyToday}';
      case DashboardSection.health:
        return l10n.healthDashboard;
      case DashboardSection.favorites:
        return l10n.favorites;
      case DashboardSection.quickScenes:
        return l10n.quickScenes;
      case DashboardSection.devices:
        return l10n.devices;
      case DashboardSection.activity:
        return l10n.activityTimeline;
      case DashboardSection.demoLab:
        return l10n.demoLab;
    }
  }

  IconData _getSectionIcon(DashboardSection section) {
    switch (section) {
      case DashboardSection.metrics:
        return Icons.speed_rounded;
      case DashboardSection.health:
        return Icons.favorite_rounded;
      case DashboardSection.favorites:
        return Icons.star_rounded;
      case DashboardSection.quickScenes:
        return Icons.play_arrow_rounded;
      case DashboardSection.devices:
        return Icons.devices_rounded;
      case DashboardSection.activity:
        return Icons.bar_chart_rounded;
      case DashboardSection.demoLab:
        return Icons.science_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle Bar
            SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 12),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dashboard_customize_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.editDashboard,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          l10n.dragToReorder,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      key: Key('dashboard_done_editing_button'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(
                        l10n.doneEditing,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
                height: 20),

            // Reorderable list
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _draftOrder.length,
                // ignore: deprecated_member_use
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final section = _draftOrder[index];
                  final isVisible = _draftVisibility[section] ?? true;

                  return Container(
                    key: Key('dashboard_edit_item_${section.name}'),
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isVisible
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.25)
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getSectionIcon(section),
                            color: isVisible
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          // Accessibility Up/Down buttons
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                button: true,
                                label: 'Move up ${section.name}',
                                child: InkWell(
                                  key: Key('move_up_${section.name}'),
                                  onTap:
                                      index > 0 ? () => _moveUp(index) : null,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 24,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      size: 20,
                                      color: index > 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: 'Move down ${section.name}',
                                child: InkWell(
                                  key: Key('move_down_${section.name}'),
                                  onTap: index < _draftOrder.length - 1
                                      ? () => _moveDown(index)
                                      : null,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 24,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: index < _draftOrder.length - 1
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      title: Text(
                        _getSectionTitle(section, l10n),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isVisible
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            key: Key('toggle_section_${section.name}'),
                            value: isVisible,
                            activeTrackColor:
                                Theme.of(context).colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                _draftVisibility[section] = val;
                              });
                            },
                          ),
                          SizedBox(width: 4),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Actions: Save and Reset
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key('reset_dashboard_layout_button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, 48),
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        side: BorderSide(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _reset,
                      icon: Icon(Icons.refresh_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.resetLayout),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: Key('save_dashboard_layout_button'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, 48),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _save,
                      icon: Icon(Icons.check_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.saveLayout),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
