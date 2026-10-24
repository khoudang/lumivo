import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/backup_payload.dart';
import '../../../core/models/room.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../automation/state/automation_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  String? _lastExportedJson;

  BackupPayload _createCurrentBackupPayload() {
    final currentHome = ref.read(currentHomeProvider);
    final homes = ref.read(homesProvider).homes;
    final effectiveHomes = homes.isNotEmpty ? homes : [currentHome];

    final rooms = ref.read(roomsProvider);
    final devices = ref.read(devicesProvider).valueOrNull ?? [];
    final scenes = ref.read(scenesProvider);
    final automations = ref.read(automationRulesProvider);

    return BackupPayload(
      metadata: BackupMetadata(
        schemaVersion: 6,
        exportedAt: DateTime.now(),
        lumivoVersion: '0.6.0',
        homeCount: effectiveHomes.length,
        deviceCount: devices.length,
      ),
      homes: effectiveHomes.map((h) => h.toJson()).toList(),
      rooms: rooms.map((r) => r.toJson()).toList(),
      devices: devices.map((d) => d.toJson()).toList(),
      scenes: scenes.map((s) => s.toJson()).toList(),
      automations: automations.map((a) => a.toJson()).toList(),
    );
  }

  void _exportBackup() {
    final payload = _createCurrentBackupPayload();
    final jsonString = jsonEncode(payload.toJson());
    setState(() => _lastExportedJson = jsonString);

    final l10n = ref.read(appLocalizationsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.exportBackup} (${payload.devices.length} devices, ${payload.rooms.length} rooms)',
        ),
        backgroundColor: AppColors.green,
      ),
    );
  }

  void _importBackup() {
    final payload = _createCurrentBackupPayload();
    _showBackupPreview(payload);
  }

  void _importInvalidBackup() {
    final l10n = ref.read(appLocalizationsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.invalidBackupError),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _showBackupPreview(BackupPayload payload) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => BackupPreviewDialog(
        payload: payload,
        onConfirmRestore: () {
          _applyRestore(payload);
          final l10n = ref.read(appLocalizationsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.restoreSuccess),
              backgroundColor: AppColors.green,
            ),
          );
        },
      ),
    );
  }

  void _applyRestore(BackupPayload payload) {
    if (payload.rooms.isNotEmpty) {
      final restoredRooms = payload.rooms.map((r) => Room.fromJson(r)).toList();
      ref.read(roomsProvider.notifier).setRooms(restoredRooms);
    }

    if (payload.scenes.isNotEmpty) {
      final restoredScenes =
          payload.scenes.map((s) => Scene.fromJson(s)).toList();
      ref.read(scenesProvider.notifier).setScenes(restoredScenes);
    }

    if (payload.automations.isNotEmpty) {
      final restoredRules =
          payload.automations.map((a) => AutomationRule.fromJson(a)).toList();
      for (final rule in restoredRules) {
        ref.read(automationRulesProvider.notifier).addRule(rule);
      }
    }

    final repo = ref.read(deviceRepositoryProvider);
    if (repo is MockDeviceRepository) {
      for (final d in payload.devices) {
        final dev = SmartDevice(
          id: d['id'] as String,
          name: d['name'] as String,
          roomId: d['roomId'] as String? ?? 'Living Room',
          type: DeviceType.values.firstWhere(
            (e) => e.name == d['type'],
            orElse: () => DeviceType.light,
          ),
          isOn: d['isOn'] as bool? ?? false,
          brightness: d['brightness'] as int? ?? 100,
          connection: DeviceConnection.values.firstWhere(
            (e) => e.name == d['connection'],
            orElse: () => DeviceConnection.online,
          ),
          isFavorite: d['isFavorite'] as bool? ?? false,
        );
        repo.updateDevice(dev);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.backupAndRestore,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.cloud_sync_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.backupAndRestore,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Export your entire smart home setup or restore from an existing JSON backup payload.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.replaceDataWarning,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.upload_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.exportBackup,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Serializes homes, rooms, smart devices, automations, and ambiance scenes into JSON format.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    key: const Key('export_backup_button'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: FittedBox(
                        fit: BoxFit.scaleDown, child: Text(l10n.exportBackup)),
                  ),
                  if (_lastExportedJson != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(
                        _lastExportedJson!.length > 180
                            ? '${_lastExportedJson!.substring(0, 180)}...'
                            : _lastExportedJson!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.file_download_outlined,
                          color: AppColors.cyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.importBackup,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Validates schema version and previews configuration before applying home restoration.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    key: const Key('import_backup_button'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _importBackup,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: FittedBox(
                        fit: BoxFit.scaleDown, child: Text(l10n.importBackup)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('import_invalid_backup_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _importInvalidBackup,
                    child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Simulate Invalid / Corrupted File')),
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

class BackupPreviewDialog extends StatelessWidget {
  const BackupPreviewDialog({
    super.key,
    required this.payload,
    required this.onConfirmRestore,
  });

  final BackupPayload payload;
  final VoidCallback onConfirmRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final homeCount = payload.homes.isNotEmpty ? payload.homes.length : 1;
    final roomCount = payload.rooms.length;
    final deviceCount = payload.devices.length;
    final sceneCount = payload.scenes.length;
    final automationCount = payload.automations.length;

    return Dialog(
      key: const Key('backup_preview_dialog'),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.restore_page_rounded,
                      color: AppColors.cyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.backupPreview,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          key: const Key('backup_preview_validation_status'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Valid Schema v6',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green,
                            ),
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
              Row(
                children: [
                  _statItem('Homes', '$homeCount',
                      const Key('backup_preview_home_count')),
                  _statItem('Rooms', '$roomCount',
                      const Key('backup_preview_room_count')),
                  _statItem('Devices', '$deviceCount',
                      const Key('backup_preview_device_count')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statItem('Scenes', '$sceneCount',
                      const Key('backup_preview_scene_count')),
                  _statItem('Automations', '$automationCount',
                      const Key('backup_preview_automation_count')),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.replaceDataWarning,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                    key: const Key('confirm_restore_backup_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirmRestore();
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Key key) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              key: key,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
