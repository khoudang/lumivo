import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

class ScenePreviewDialog extends ConsumerWidget {
  const ScenePreviewDialog({
    super.key,
    required this.actions,
    this.title,
    this.onConfirm,
  });

  final List<DeviceAction> actions;
  final String? title;
  final VoidCallback? onConfirm;

  static Future<void> show(
    BuildContext context, {
    required List<DeviceAction> actions,
    String? title,
    VoidCallback? onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ScenePreviewDialog(
        actions: actions,
        title: title,
        onConfirm: onConfirm,
      ),
    );
  }

  String _formatCurrentValue(SmartDevice? dev, DeviceCommandType cmd) {
    if (dev == null) return 'Off';
    switch (cmd) {
      case DeviceCommandType.setPower:
        return dev.isOn ? 'ON' : 'OFF';
      case DeviceCommandType.setBrightness:
        return '${dev.brightness}%';
      case DeviceCommandType.setTargetTemperature:
        return '${dev.targetTemperature.toStringAsFixed(0)}°C';
      case DeviceCommandType.setPosition:
        return '${dev.position}%';
      case DeviceCommandType.setLock:
      case DeviceCommandType.toggleLock:
        return dev.isLocked ? 'Locked' : 'Unlocked';
    }
  }

  String _formatTargetValue(DeviceAction action) {
    switch (action.commandType) {
      case DeviceCommandType.setPower:
        return action.value == true ? 'ON' : 'OFF';
      case DeviceCommandType.setBrightness:
        return '${action.value}%';
      case DeviceCommandType.setTargetTemperature:
        return '${action.value}°C';
      case DeviceCommandType.setPosition:
        return '${action.value}%';
      case DeviceCommandType.setLock:
      case DeviceCommandType.toggleLock:
        return action.value == true ? 'Locked' : 'Unlocked';
    }
  }

  IconData _getCommandIcon(DeviceCommandType cmd) {
    switch (cmd) {
      case DeviceCommandType.setPower:
        return Icons.power_settings_new_rounded;
      case DeviceCommandType.setBrightness:
        return Icons.wb_sunny_rounded;
      case DeviceCommandType.setTargetTemperature:
        return Icons.thermostat_rounded;
      case DeviceCommandType.setPosition:
        return Icons.curtains_rounded;
      case DeviceCommandType.setLock:
      case DeviceCommandType.toggleLock:
        return Icons.lock_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final allDevices = devicesAsync.valueOrNull ?? [];
    final deviceMap = {for (final d in allDevices) d.id: d};

    return Dialog(
      key: const Key('scene_preview_dialog'),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.visibility_rounded,
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
                          title ?? l10n.previewScene,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${actions.length} ${l10n.affectedDevices}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.surfaceBorder, height: 24),

              // Affected Devices List
              Flexible(
                child: actions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No affected devices configured.',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: actions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          final device = deviceMap[action.deviceId];
                          final devName = device?.name ?? action.deviceId;
                          final devRoom = device?.roomId ?? 'Home';
                          final currentVal =
                              _formatCurrentValue(device, action.commandType);
                          final targetVal = _formatTargetValue(action);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getCommandIcon(action.commandType),
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        devName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        devRoom,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // State Transition: Current -> Target
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentVal,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        targetVal,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.cyan,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('confirm_scene_execute_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm?.call();
                    },
                    child: Text(l10n.done),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
