import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/theme/app_theme.dart';
import '../../activity/state/activity_providers.dart';
import '../state/automation_providers.dart';
import 'create_automation_screen.dart';

class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _runScene(Scene scene) async {
    for (final action in scene.actions) {
      await ref.read(deviceRepositoryProvider).sendCommand(
            DeviceCommand(
              requestId: 'scene-${DateTime.now().millisecondsSinceEpoch}',
              deviceId: action.deviceId,
              type: action.commandType,
              value: action.value,
            ),
          );
    }

    ref.read(activityProvider.notifier).addEvent(
          ActivityEvent(
            id: 'act-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Scene "${scene.name}" Executed',
            description: '${scene.actions.length} commands applied to devices',
            timestamp: DateTime.now(),
            severity: ActivitySeverity.success,
            source: 'automation',
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scene "${scene.name}" executed successfully!'),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'automation_fab',
        key: const Key('add_automation_fab'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateAutomationScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Add Automation',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROUTINES & LOGIC',
                            style: TextStyle(
                              letterSpacing: 1.5,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Automation',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add_rounded, size: 22),
                        tooltip: 'New Rule',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateAutomationScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.muted,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(text: 'Automations'),
                        Tab(text: 'Scenes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAutomationsTab(),
                  _buildScenesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationsTab() {
    final rules = ref.watch(automationRulesProvider);

    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text(
              'No automations configured',
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 80),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _buildRuleCard(rule);
      },
    );
  }

  Widget _buildRuleCard(AutomationRule rule) {
    final triggerSummary = _formatTrigger(rule);
    final actionSummary = _formatAction(rule);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: rule.isEnabled
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.surfaceBorder,
          width: rule.isEnabled ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: rule.isEnabled
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  rule.triggerType == TriggerType.schedule
                      ? Icons.alarm_rounded
                      : Icons.sensors_rounded,
                  color: rule.isEnabled ? AppColors.primary : AppColors.muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rule.isEnabled ? 'Enabled & Active' : 'Disabled',
                      style: TextStyle(
                        fontSize: 11,
                        color: rule.isEnabled
                            ? AppColors.green
                            : AppColors.mutedDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.isEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (_) {
                  ref
                      .read(automationRulesProvider.notifier)
                      .toggleRule(rule.id);
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.muted,
                  size: 20,
                ),
                tooltip: 'Delete',
                onPressed: () {
                  ref
                      .read(automationRulesProvider.notifier)
                      .deleteRule(rule.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rule "${rule.name}" deleted'),
                      backgroundColor: AppColors.surfaceElevated,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                Icons.arrow_forward_rounded,
                triggerSummary,
                AppColors.cyan,
              ),
              _summaryChip(
                Icons.bolt_rounded,
                actionSummary,
                AppColors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTrigger(AutomationRule rule) {
    if (rule.triggerType == TriggerType.schedule) {
      final days = rule.daysOfWeek.length == 7
          ? 'Everyday'
          : rule.daysOfWeek.length == 5 && !rule.daysOfWeek.contains(6)
              ? 'Mon-Fri'
              : '${rule.daysOfWeek.length} days/wk';
      return '⏰ ${rule.timeOfDay ?? "07:00"} · $days';
    } else {
      final op = rule.operator == ComparisonOperator.greaterThan
          ? '>'
          : rule.operator == ComparisonOperator.lessThan
              ? '<'
              : '=';
      final unit = rule.sensorProperty == 'temperature' ? '°C' : '%';
      return '🌡️ ${rule.sensorProperty} $op ${rule.thresholdValue.toStringAsFixed(0)}$unit';
    }
  }

  String _formatAction(AutomationRule rule) {
    if (rule.actions.isEmpty) return 'No action';
    final a = rule.actions.first;
    switch (a.commandType) {
      case DeviceCommandType.setPower:
        return 'Turn ${a.value == true ? "ON" : "OFF"} (${a.deviceId})';
      case DeviceCommandType.setTargetTemperature:
        return 'Set Temp to ${a.value}°C';
      case DeviceCommandType.setBrightness:
        return 'Set Brightness ${a.value}%';
      case DeviceCommandType.setPosition:
        return 'Curtain Position ${a.value}%';
      case DeviceCommandType.setLock:
      case DeviceCommandType.toggleLock:
        return 'Lock Security Door';
    }
  }

  Widget _buildScenesTab() {
    final scenes = ref.watch(scenesProvider);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 80),
      itemCount: scenes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final scene = scenes[index];
        final icon = _sceneIcon(scene.iconName);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${scene.actions.length} automated steps',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                key: Key('run_scene_${scene.id}'),
                onPressed: () => _runScene(scene),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run Scene'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _sceneIcon(String name) {
    switch (name) {
      case 'wb_sunny_rounded':
        return Icons.wb_sunny_rounded;
      case 'logout_rounded':
        return Icons.logout_rounded;
      case 'bedtime_rounded':
        return Icons.bedtime_rounded;
      case 'movie_rounded':
        return Icons.movie_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}
