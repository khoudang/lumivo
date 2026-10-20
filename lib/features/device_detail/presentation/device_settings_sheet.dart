import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';

class DeviceSettingsSheet extends ConsumerStatefulWidget {
  const DeviceSettingsSheet({
    super.key,
    required this.device,
    this.onSave,
    this.onDelete,
  });

  final SmartDevice device;
  final void Function(SmartDevice updatedDevice)? onSave;
  final void Function(String deviceId)? onDelete;

  static Future<void> show(
    BuildContext context,
    SmartDevice device, {
    void Function(SmartDevice updatedDevice)? onSave,
    void Function(String deviceId)? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceSettingsSheet(
        device: device,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  ConsumerState<DeviceSettingsSheet> createState() =>
      _DeviceSettingsSheetState();
}

class _DeviceSettingsSheetState extends ConsumerState<DeviceSettingsSheet> {
  late TextEditingController _nameController;
  late bool _isFavorite;
  late String _selectedRoom;
  String? _selectedIcon;

  static const Map<String, (IconData, String)> curatedIcons = {
    'bulb': (Icons.lightbulb_rounded, 'Bulb'),
    'desk_lamp': (Icons.desk_rounded, 'Desk Lamp'),
    'ceiling_light': (Icons.wb_incandescent_rounded, 'Ceiling Light'),
    'fan': (Icons.mode_fan_off_outlined, 'Fan'),
    'ac_unit': (Icons.ac_unit_rounded, 'AC Unit'),
    'power': (Icons.power_rounded, 'Power'),
    'lock': (Icons.lock_rounded, 'Lock'),
    'window': (Icons.curtains_rounded, 'Window'),
    'sensor': (Icons.sensors_rounded, 'Sensor'),
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
    _isFavorite = widget.device.isFavorite;
    _selectedRoom = widget.device.roomId;
    _selectedIcon = widget.device.customIcon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text(
              'Delete Device?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.device.name}"? This removes the device and cascades to all scenes & automations referencing it. This action cannot be undone.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_device_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final repo = ref.read(deviceRepositoryProvider);
              if (repo is MockDeviceRepository) {
                repo.removeDevice(widget.device.id);
              }

              // Cascade delete from scenes
              final scenes = ref.read(scenesProvider);
              for (final scene in scenes) {
                final filtered = scene.actions
                    .where((a) => a.deviceId != widget.device.id)
                    .toList();
                if (filtered.length != scene.actions.length) {
                  ref
                      .read(scenesProvider.notifier)
                      .updateScene(scene.copyWith(actions: filtered));
                }
              }

              widget.onDelete?.call(widget.device.id);

              Navigator.of(dialogCtx).pop(); // Close dialog
              Navigator.of(context).pop(); // Close sheet

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Device "${widget.device.name}" deleted.'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _saveChanges() {
    final name = _nameController.text.trim();
    final updated = widget.device.copyWith(
      name: name.isEmpty ? widget.device.name : name,
      customIcon: _selectedIcon,
      isFavorite: _isFavorite,
      roomId: _selectedRoom,
    );

    final repo = ref.read(deviceRepositoryProvider);
    if (repo is MockDeviceRepository) {
      repo.updateDevice(updated);
    }

    widget.onSave?.call(updated);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device settings saved successfully!'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsList = ref.watch(roomsProvider);
    final roomNames = roomsList.map((r) => r.name).toList();
    if (!roomNames.contains(_selectedRoom)) {
      roomNames.insert(0, _selectedRoom);
    }

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

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Customize naming, icons, and room placement',
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

              // Rename Device Field
              const Text(
                'Device Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('device_settings_name_input'),
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter device name',
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

              // Custom Icon Selector
              const Text(
                'Custom Icon',
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
                children: curatedIcons.entries.map((entry) {
                  final isSelected = _selectedIcon == entry.key;
                  return InkWell(
                    key: Key('custom_icon_${entry.key}'),
                    onTap: () {
                      setState(() {
                        _selectedIcon = isSelected ? null : entry.key;
                      });
                    },
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8,
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

              const SizedBox(height: 20),

              // Favorite Toggle Switch
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    key: const Key('device_settings_favorite_switch'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: const Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: Color(0xFFFFD572), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Pin to Favorites',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text(
                      'Quick access on dashboard favorites shelf',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    value: _isFavorite,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isFavorite = val),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Room Assignment Dropdown
              const Text(
                'Room Assignment',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('device_settings_room_dropdown'),
                    value: _selectedRoom,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    icon: const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.muted),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    items: roomNames.map((r) {
                      return DropdownMenuItem<String>(
                        value: r,
                        child: Row(
                          children: [
                            const Icon(Icons.meeting_room_outlined,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(r),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRoom = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Action Buttons: Save & Delete
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('device_settings_delete_button'),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                      label: const Text(
                        'Delete Device',
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
                      onPressed: _confirmDelete,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('device_settings_save_button'),
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saveChanges,
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
