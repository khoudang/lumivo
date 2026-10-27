import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

class SceneEditorSheet extends ConsumerStatefulWidget {
  const SceneEditorSheet({
    super.key,
    this.initialScene,
    this.onSave,
    this.onDelete,
  });

  final Scene? initialScene;
  final void Function(Scene scene)? onSave;
  final void Function(String sceneId)? onDelete;

  static Future<void> show(
    BuildContext context, {
    Scene? scene,
    void Function(Scene)? onSave,
    void Function(String)? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SceneEditorSheet(
        initialScene: scene,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  ConsumerState<SceneEditorSheet> createState() => _SceneEditorSheetState();
}

class _SceneEditorSheetState extends ConsumerState<SceneEditorSheet> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late List<DeviceAction> _actions;

  static const Map<String, (IconData, String)> sceneIcons = {
    'auto_awesome': (Icons.auto_awesome_rounded, 'Magic'),
    'wb_sunny_rounded': (Icons.wb_sunny_rounded, 'Morning'),
    'bedtime_rounded': (Icons.bedtime_rounded, 'Night'),
    'movie_rounded': (Icons.movie_rounded, 'Cinema'),
    'logout_rounded': (Icons.logout_rounded, 'Leave'),
    'coffee': (Icons.coffee_rounded, 'Coffee'),
    'local_fire_department': (Icons.local_fire_department_rounded, 'Warm'),
    'shield': (Icons.shield_rounded, 'Security'),
  };

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialScene?.name ?? '');
    _selectedIcon = widget.initialScene?.iconName ?? 'auto_awesome';
    _actions = List.of(widget.initialScene?.actions ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddActionDialog() {
    final l10n = ref.read(appLocalizationsProvider);
    final devicesAsync = ref.read(devicesProvider);
    final devices = devicesAsync.valueOrNull ?? [];

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noDevicesAvailableScene),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String selectedDeviceId = devices.first.id;
    DeviceCommandType selectedCommand = DeviceCommandType.setPower;
    Object targetValue = true;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentDev = devices.firstWhere(
            (d) => d.id == selectedDeviceId,
            orElse: () => devices.first,
          );

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            title: Row(
              children: [
                Icon(Icons.add_task_rounded,
                    color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Add Scene Action',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Device',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('action_select_device_dropdown'),
                        value: selectedDeviceId,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceElevated,
                        items: devices.map((d) {
                          return DropdownMenuItem<String>(
                            value: d.id,
                            child: Text(
                              '${d.name} (${d.roomId})',
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDeviceId = val;
                              // Default command based on device
                              final dev =
                                  devices.firstWhere((d) => d.id == val);
                              if (dev.type == DeviceType.ac) {
                                selectedCommand =
                                    DeviceCommandType.setTargetTemperature;
                                targetValue = 22.0;
                              } else {
                                selectedCommand = DeviceCommandType.setPower;
                                targetValue = true;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Command Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DeviceCommandType>(
                        key: const Key('action_command_type_dropdown'),
                        value: selectedCommand,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceElevated,
                        items: [
                          const DropdownMenuItem(
                            value: DeviceCommandType.setPower,
                            child: Text('Power (On / Off)',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13)),
                          ),
                          if (currentDev.type == DeviceType.light)
                            const DropdownMenuItem(
                              value: DeviceCommandType.setBrightness,
                              child: Text('Brightness (%)',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                            ),
                          if (currentDev.type == DeviceType.ac)
                            const DropdownMenuItem(
                              value: DeviceCommandType.setTargetTemperature,
                              child: Text('Target Temperature (°C)',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                            ),
                          if (currentDev.type == DeviceType.curtain)
                            const DropdownMenuItem(
                              value: DeviceCommandType.setPosition,
                              child: Text('Position (%)',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                            ),
                          if (currentDev.type == DeviceType.lock)
                            const DropdownMenuItem(
                              value: DeviceCommandType.setLock,
                              child: Text('Lock / Unlock',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCommand = val;
                              switch (val) {
                                case DeviceCommandType.setPower:
                                  targetValue = true;
                                  break;
                                case DeviceCommandType.setBrightness:
                                  targetValue = 80;
                                  break;
                                case DeviceCommandType.setTargetTemperature:
                                  targetValue = 23.0;
                                  break;
                                case DeviceCommandType.setPosition:
                                  targetValue = 100;
                                  break;
                                case DeviceCommandType.setLock:
                                  targetValue = true;
                                  break;
                                case DeviceCommandType.toggleLock:
                                  targetValue = true;
                                  break;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Target Value',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (selectedCommand == DeviceCommandType.setPower ||
                      selectedCommand == DeviceCommandType.setLock)
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(
                              selectedCommand == DeviceCommandType.setLock
                                  ? 'Locked'
                                  : 'Turn ON'),
                          selected: targetValue == true,
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.25),
                          backgroundColor: AppColors.surfaceElevated,
                          labelStyle: TextStyle(
                            color: targetValue == true
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          onSelected: (val) {
                            if (val) setDialogState(() => targetValue = true);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                              selectedCommand == DeviceCommandType.setLock
                                  ? 'Unlocked'
                                  : 'Turn OFF'),
                          selected: targetValue == false,
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.25),
                          backgroundColor: AppColors.surfaceElevated,
                          labelStyle: TextStyle(
                            color: targetValue == false
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          onSelected: (val) {
                            if (val) setDialogState(() => targetValue = false);
                          },
                        ),
                      ],
                    )
                  else if (selectedCommand ==
                      DeviceCommandType.setTargetTemperature)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: AppColors.primary),
                          onPressed: () {
                            final current = (targetValue as num).toDouble();
                            if (current > 16.0) {
                              setDialogState(() => targetValue = current - 1.0);
                            }
                          },
                        ),
                        Text(
                          '${(targetValue as num).toDouble().toStringAsFixed(0)}°C',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              color: AppColors.primary),
                          onPressed: () {
                            final current = (targetValue as num).toDouble();
                            if (current < 30.0) {
                              setDialogState(() => targetValue = current + 1.0);
                            }
                          },
                        ),
                      ],
                    )
                  else
                    Slider(
                      value: (targetValue as num).toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: '${(targetValue as num).round()}%',
                      activeColor: AppColors.primary,
                      onChanged: (val) =>
                          setDialogState(() => targetValue = val.round()),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                key: const Key('confirm_add_action_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final action = DeviceAction(
                    deviceId: selectedDeviceId,
                    commandType: selectedCommand,
                    value: targetValue,
                  );
                  setState(() {
                    _actions.add(action);
                  });
                  Navigator.of(dialogCtx).pop();
                },
                child: Text(l10n.addAction),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveScene() {
    final l10n = ref.read(appLocalizationsProvider);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterSceneName),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final scene = Scene(
      id: widget.initialScene?.id ??
          'scene-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      iconName: _selectedIcon,
      actions: _actions,
    );

    if (widget.initialScene != null) {
      ref.read(scenesProvider.notifier).updateScene(scene);
    } else {
      ref.read(scenesProvider.notifier).addScene(scene);
    }

    widget.onSave?.call(scene);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.sceneSaved(name)),
        backgroundColor: AppColors.green,
      ),
    );
  }

  void _deleteScene() {
    if (widget.initialScene == null) return;
    final l10n = ref.read(appLocalizationsProvider);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 24),
            SizedBox(width: 8),
            Text(
              l10n.confirmDeleteSceneTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete scene "${widget.initialScene!.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_scene_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              ref
                  .read(scenesProvider.notifier)
                  .deleteScene(widget.initialScene!.id);
              widget.onDelete?.call(widget.initialScene!.id);
              Navigator.of(dialogCtx).pop(); // Close dialog
              Navigator.of(context).pop(); // Close sheet
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final devices = devicesAsync.valueOrNull ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialScene == null
                              ? 'Create New Scene'
                              : 'Edit Scene',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'One-tap multi-device ambiance automation',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.muted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Scene Name Input
              const Text(
                'Scene Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('scene_editor_name_input'),
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Movie Night, Good Morning',
                  hintStyle: const TextStyle(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Icon Picker
              const Text(
                'Scene Icon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: sceneIcons.entries.map((entry) {
                  final isSelected = _selectedIcon == entry.key;
                  return InkWell(
                    key: Key('scene_icon_${entry.key}'),
                    onTap: () => setState(() => _selectedIcon = entry.key),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.22)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected ? AppShadows.primaryGlow : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            entry.value.$1,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.muted,
                            size: 22,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.value.$2,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Multi-Device Actions Section
              Row(
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Device Actions',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_actions.length}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: const Key('scene_editor_add_action_button'),
                    icon: const Icon(Icons.add_rounded,
                        size: 18, color: AppColors.primary),
                    label: const Text(
                      'Add Action',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: _showAddActionDialog,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_actions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No device actions added yet.\nTap "+ Add Action" to configure device states.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _actions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final action = _actions[idx];
                    final dev = devices.firstWhere(
                      (d) => d.id == action.deviceId,
                      orElse: () => SmartDevice(
                        id: action.deviceId,
                        name: 'Device (${action.deviceId})',
                        roomId: 'General',
                        type: DeviceType.light,
                        isOn: false,
                      ),
                    );

                    final actionDescription = switch (action.commandType) {
                      DeviceCommandType.setPower =>
                        'Set Power: ${action.value == true ? "ON" : "OFF"}',
                      DeviceCommandType.setBrightness =>
                        'Set Brightness: ${action.value}%',
                      DeviceCommandType.setTargetTemperature =>
                        'Set Temperature: ${action.value}°C',
                      DeviceCommandType.setPosition =>
                        'Curtain Position: ${action.value}%',
                      DeviceCommandType.setLock ||
                      DeviceCommandType.toggleLock =>
                        'Lock State: ${action.value == true ? "Locked" : "Unlocked"}',
                    };

                    return Container(
                      key: Key('scene_action_item_$idx'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bolt_rounded,
                                color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  actionDescription,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.cyan,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: Key('delete_scene_action_$idx'),
                            icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 18,
                                color: AppColors.danger),
                            onPressed: () {
                              setState(() => _actions.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              // Action Buttons: Save & Delete Scene
              Row(
                children: [
                  if (widget.initialScene != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('scene_editor_delete_button'),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger, size: 20),
                        label: const Text(
                          'Delete Scene',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _deleteScene,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('scene_editor_save_button'),
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        widget.initialScene == null
                            ? 'Create Scene'
                            : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saveScene,
                    ),
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
