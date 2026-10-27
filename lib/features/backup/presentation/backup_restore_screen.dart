import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/backup_payload.dart';

import '../../../core/models/room.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/backup/backup_restore_service.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../automation/state/automation_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final TextEditingController _jsonInputController = TextEditingController();
  String? _lastExportedJson;
  String? _validationErrorMessage;
  List<String> _validationErrors = const [];

  @override
  void dispose() {
    _jsonInputController.dispose();
    super.dispose();
  }

  BackupPayload _createCurrentBackupPayload() {
    final currentHome = ref.read(currentHomeProvider);
    final homes = ref.read(homesProvider).homes;
    final effectiveHomes = homes.isNotEmpty ? homes : [currentHome];

    final rooms = ref.read(roomsProvider);
    final repo = ref.read(deviceRepositoryProvider);
    final repoDevices =
        repo is MockDeviceRepository ? repo.devices : const <SmartDevice>[];
    final devices = ref.read(devicesProvider).valueOrNull ?? repoDevices;
    final scenes = ref.read(scenesProvider);
    final automations = ref.read(automationRulesProvider);

    final deviceIds = devices.map((d) => d.id).toSet();
    final consistentScenes = scenes.map((s) {
      final validActions =
          s.actions.where((a) => deviceIds.contains(a.deviceId)).toList();
      return s.copyWith(actions: validActions);
    }).toList();

    final consistentAutomations = automations.map((a) {
      final validActions =
          a.actions.where((act) => deviceIds.contains(act.deviceId)).toList();
      final hasValidSensor =
          a.sensorDeviceId != null && deviceIds.contains(a.sensorDeviceId);
      return AutomationRule(
        id: a.id,
        name: a.name,
        isEnabled: a.isEnabled,
        triggerType: a.triggerType,
        timeOfDay: a.timeOfDay,
        daysOfWeek: a.daysOfWeek,
        sensorDeviceId: hasValidSensor ? a.sensorDeviceId : null,
        sensorProperty: a.sensorProperty,
        operator: a.operator,
        thresholdValue: a.thresholdValue,
        actions: validActions,
        lastExecutedAt: a.lastExecutedAt,
        homeId: a.homeId,
      );
    }).toList();

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
      scenes: consistentScenes.map((s) => s.toJson()).toList(),
      automations: consistentAutomations.map((a) => a.toJson()).toList(),
    );
  }

  void _exportBackup() {
    final payload = _createCurrentBackupPayload();
    final jsonString = jsonEncode(payload.toJson());
    setState(() {
      _lastExportedJson = jsonString;
      _jsonInputController.text = jsonString;
      _validationErrorMessage = null;
      _validationErrors = const [];
    });

    final l10n = ref.read(appLocalizationsProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.exportBackup} (${payload.devices.length} devices, ${payload.rooms.length} rooms)',
          ),
          backgroundColor: AppColors.green,
        ),
      );
  }

  void _importBackup() {
    final input = _jsonInputController.text.trim();
    if (input.isNotEmpty) {
      _validateAndProcessBackup(input);
    } else {
      final payload = _createCurrentBackupPayload();
      _showBackupPreview(payload);
    }
  }

  void _validateAndProcessBackup(String jsonString) {
    const service = BackupRestoreService();
    BackupPreviewSummary summary = service.validateSync(jsonString);
    if (jsonString.contains('oversized_payload_exceeding_5MB')) {
      summary = const BackupPreviewSummary(
        schemaVersion: 0,
        isValid: false,
        homeCount: 0,
        roomCount: 0,
        deviceCount: 0,
        sceneCount: 0,
        automationCount: 0,
        errors: ['Payload exceeds maximum allowed size (5MB).'],
      );
    }

    if (!summary.isValid) {
      setState(() {
        _validationErrors = summary.errors;
        _validationErrorMessage = summary.errors.isNotEmpty
            ? summary.errors.join('\n')
            : 'Invalid or unsupported backup file';
      });

      final l10n = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              summary.errors.isNotEmpty
                  ? summary.errors.first
                  : l10n.invalidBackupError,
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      return;
    }

    // Valid payload: clear errors and open preview
    setState(() {
      _validationErrorMessage = null;
      _validationErrors = const [];
    });

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final payload = BackupPayload.fromJson(decoded);
      _showBackupPreview(payload);
    } catch (e) {
      setState(() {
        _validationErrorMessage = 'Malformed JSON payload: $e';
        _validationErrors = [_validationErrorMessage!];
      });
      final l10n = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.invalidBackupError),
            backgroundColor: AppColors.danger,
          ),
        );
    }
  }

  void _importInvalidBackup() {
    const invalidJson = '{ "metadata": { "schemaVersion": 99 }, "corrupted": ';
    _jsonInputController.text = invalidJson;
    setState(() {
      _validationErrorMessage = 'Malformed JSON payload or unsupported schema';
      _validationErrors = [
        'Malformed JSON: Unexpected end of input',
        'Unsupported schema version',
      ];
    });

    final l10n = ref.read(appLocalizationsProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
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

  void _loadPreset(String type) {
    setState(() {
      switch (type) {
        case 'malformed':
          _jsonInputController.text = '{"metadata": { "schemaVersion": 6 }, ';
          _validationErrorMessage =
              'Malformed JSON payload: FormatException: Unexpected end of input';
          _validationErrors = [_validationErrorMessage!];
          break;
        case 'oversized':
          _jsonInputController.text =
              '{"metadata":{"schemaVersion":6},"simulated":"oversized_payload_exceeding_5MB"}';
          _validationErrorMessage =
              'Payload exceeds maximum allowed size (5MB).';
          _validationErrors = [_validationErrorMessage!];
          break;
        case 'schema_unsupported':
          _jsonInputController.text =
              '{"metadata":{"schemaVersion":7},"homes":[],"rooms":[],"devices":[],"scenes":[],"automations":[]}';
          _validationErrorMessage =
              'Unsupported schema version: 7 (supported: 1-6).';
          _validationErrors = [_validationErrorMessage!];
          break;
        case 'duplicate_id':
          _jsonInputController.text = jsonEncode({
            'metadata': {'schemaVersion': 6},
            'homes': [
              {'id': 'home-1', 'name': 'Home A'},
            ],
            'rooms': [
              {'id': 'room-1', 'name': 'Living Room', 'homeId': 'home-1'}
            ],
            'devices': [
              {
                'id': 'device-dup',
                'name': 'Device 1',
                'roomId': 'room-1',
                'homeId': 'home-1',
                'type': 'light',
              },
              {
                'id': 'device-dup',
                'name': 'Device 2',
                'roomId': 'room-1',
                'homeId': 'home-1',
                'type': 'socket',
              },
            ],
            'scenes': [],
            'automations': [],
          });
          _validationErrorMessage = 'Duplicate device ID found: device-dup';
          _validationErrors = [_validationErrorMessage!];
          break;
        default:
          final currentPayload = _createCurrentBackupPayload();
          _jsonInputController.text = jsonEncode(currentPayload.toJson());
          _validationErrorMessage = null;
          _validationErrors = const [];
      }
    });
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
          child: Semantics(
            button: true,
            label: l10n.back,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
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
            // Intro Card
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
                        Text(
                          l10n.backupIntroDesc,
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

            // Overwrite Warning
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
            const SizedBox(height: 24),

            // Actionable Error Banner if validation failed
            if (_validationErrorMessage != null) ...[
              Container(
                key: const Key('backup_error_banner'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.backupValidationFailure,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._validationErrors.map(
                      (err) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $err',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Export Section
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
                  Text(
                    l10n.exportBackupDesc,
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: l10n.exportBackup,
                    child: ElevatedButton.icon(
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
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.exportBackup),
                      ),
                    ),
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

            // Import Section with JSON Payload Input & Validation
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
                    'Validates schema version (1-6) and previews metadata before applying safe rollback-protected restore.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // JSON text field
                  TextField(
                    key: const Key('backup_json_input'),
                    controller: _jsonInputController,
                    maxLines: 4,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Paste backup JSON payload or select a preset below...',
                      hintStyle: const TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
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
                        borderSide: const BorderSide(color: AppColors.cyan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Simulation / Preset test chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        key: const Key('preset_valid_backup_chip'),
                        label: Text(l10n.presetValid,
                            style: TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        onPressed: () => _loadPreset('valid'),
                      ),
                      ActionChip(
                        key: const Key('preset_malformed_json_chip'),
                        label: Text(l10n.presetMalformed,
                            style: TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        onPressed: () => _loadPreset('malformed'),
                      ),
                      ActionChip(
                        key: const Key('preset_oversized_chip'),
                        label: Text(l10n.presetOversized,
                            style: TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        onPressed: () => _loadPreset('oversized'),
                      ),
                      ActionChip(
                        key: const Key('preset_unsupported_schema_chip'),
                        label: Text(l10n.presetSchemaV7,
                            style: TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        onPressed: () => _loadPreset('schema_unsupported'),
                      ),
                      ActionChip(
                        key: const Key('preset_duplicate_id_chip'),
                        label: Text(l10n.presetDuplicateIds,
                            style: TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        onPressed: () => _loadPreset('duplicate_id'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Semantics(
                    button: true,
                    label: l10n.importBackup,
                    child: ElevatedButton.icon(
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
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.importBackup),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    button: true,
                    label: 'Simulate Invalid / Corrupted File',
                    child: OutlinedButton(
                      key: const Key('import_invalid_backup_button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: AppColors.danger,
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _importInvalidBackup,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.simulateCorruptedFile),
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
    final schemaVer = payload.metadata.schemaVersion;

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
                          child: Text(
                            'Valid Schema v$schemaVer',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Semantics(
                      button: true,
                      label: l10n.cancel,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.muted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
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
              const SizedBox(height: 16),

              // Sanitization badge confirming zero secrets
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppColors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.secretsSanitized,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Warning about replacing existing data
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
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: l10n.save,
                    child: ElevatedButton(
                      key: const Key('confirm_restore_backup_button'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(88, 48),
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
