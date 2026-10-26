import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../automation/state/automation_providers.dart';
import '../../backup/presentation/backup_restore_screen.dart';

class RecoveryCenterScreen extends ConsumerStatefulWidget {
  const RecoveryCenterScreen({super.key});

  @override
  ConsumerState<RecoveryCenterScreen> createState() =>
      _RecoveryCenterScreenState();
}

class _RecoveryCenterScreenState extends ConsumerState<RecoveryCenterScreen> {
  bool _isLoading = false;
  bool _hasSnapshot = false;

  @override
  void initState() {
    super.initState();
    _checkSnapshotStatus();
  }

  Future<void> _checkSnapshotStatus() async {
    final persistence = ref.read(homePersistenceProvider);
    final has = await persistence.hasSnapshot();
    if (mounted) {
      setState(() {
        _hasSnapshot = has;
      });
    }
  }

  Future<void> _retryLoadState() async {
    setState(() => _isLoading = true);
    final persistence = ref.read(homePersistenceProvider);
    final state = await persistence.loadHomeState();

    final repo = ref.read(deviceRepositoryProvider);
    if (repo is MockDeviceRepository) {
      if (state.devices.isNotEmpty) {
        for (final d in state.devices) {
          repo.updateDevice(d);
        }
      }
    }
    if (state.rooms.isNotEmpty) {
      ref.read(roomsProvider.notifier).setRooms(state.rooms);
    }
    if (state.scenes.isNotEmpty) {
      ref.read(scenesProvider.notifier).setScenes(state.scenes);
    }
    if (state.automations.isNotEmpty) {
      ref.read(automationRulesProvider.notifier).setRules(state.automations);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      final l10n = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recoveryStateReloaded),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  Future<void> _createSnapshot() async {
    setState(() => _isLoading = true);
    final persistence = ref.read(homePersistenceProvider);
    await persistence.saveSnapshot();
    await _checkSnapshotStatus();
    if (mounted) {
      setState(() => _isLoading = false);
      final l10n = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recoverySnapshotCreated),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  Future<void> _restoreSnapshot() async {
    if (!_hasSnapshot) return;

    setState(() => _isLoading = true);
    final persistence = ref.read(homePersistenceProvider);
    final success = await persistence.restoreSnapshot();

    if (success) {
      final state = persistence.cachedState;
      if (state != null) {
        final repo = ref.read(deviceRepositoryProvider);
        if (repo is MockDeviceRepository) {
          for (final d in state.devices) {
            repo.updateDevice(d);
          }
        }
        ref.read(roomsProvider.notifier).setRooms(state.rooms);
        ref.read(scenesProvider.notifier).setScenes(state.scenes);
        ref.read(automationRulesProvider.notifier).setRules(state.automations);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      final l10n = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.recoverySnapshotRestored : l10n.invalidBackupError,
          ),
          backgroundColor: success ? AppColors.green : AppColors.danger,
        ),
      );
    }
  }

  void _showFactoryResetConfirmation() {
    final l10n = ref.read(appLocalizationsProvider);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded,
                color: AppColors.danger, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.confirmFactoryReset,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.factoryResetWarning,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                l10n.cancel,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.confirmFactoryReset,
            child: ElevatedButton(
              key: const Key('confirm_factory_reset_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 48),
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final persistence = ref.read(homePersistenceProvider);
                await persistence.resetDemoData();

                final repo = ref.read(deviceRepositoryProvider);
                if (repo is MockDeviceRepository) {
                  repo.resetToDefaults();
                }
                ref.read(roomsProvider.notifier).reset();
                ref.read(automationRulesProvider.notifier).reset();
                ref.read(activityProvider.notifier).reset();
                ref.read(notificationsProvider.notifier).reset();

                await _checkSnapshotStatus();
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.factoryResetDone),
                      backgroundColor: AppColors.green,
                    ),
                  );
                }
              },
              child: Text(l10n.confirmFactoryReset),
            ),
          ),
        ],
      ),
    );
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
            l10n.recoveryCenter,
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
            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E1C2B), Color(0xFF1B1822)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.healing_rounded,
                      color: AppColors.warning,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.recoveryCenter,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.recoverySubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Diagnostic status & snapshot indicator
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Snapshot Health Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _hasSnapshot
                              ? AppColors.green.withValues(alpha: 0.16)
                              : AppColors.muted.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _hasSnapshot
                                ? AppColors.green.withValues(alpha: 0.4)
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        child: Text(
                          _hasSnapshot
                              ? l10n.recoverySnapshotAvailable
                              : l10n.recoveryNoSnapshot,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _hasSnapshot
                                ? AppColors.green
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasSnapshot
                        ? 'A point-in-time snapshot is securely cached on-device for instantaneous rollback.'
                        : 'No valid snapshot currently exists. You can create one below or restore from a JSON backup.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Recovery Actions
            const Text(
              'RECOVERY & ROLLBACK ACTIONS',
              style: TextStyle(
                letterSpacing: 1.5,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            // 1. Retry Loading State
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.refresh_rounded,
                          color: AppColors.cyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.recoveryRetryLoad,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Re-reads the local persistence layer into memory and reconciles UI state without altering stored data.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: l10n.recoveryRetryLoad,
                    child: ElevatedButton.icon(
                      key: const Key('recovery_retry_load_button'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _retryLoadState,
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.recoveryRetryLoad),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Snapshot management: Restore or Create
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_toggle_off_rounded,
                          color: AppColors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.recoveryRestoreSnapshot,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _hasSnapshot
                        ? 'Restore the last known-good configuration snapshot saved on this device.'
                        : 'No valid snapshot exists. Creating one now captures current verified state for future recovery.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: l10n.recoveryRestoreSnapshot,
                          child: ElevatedButton.icon(
                            key: const Key('recovery_restore_snapshot_button'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.surfaceElevated,
                              disabledForegroundColor: AppColors.muted,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: (_isLoading || !_hasSnapshot)
                                ? null
                                : _restoreSnapshot,
                            icon: const Icon(Icons.restore_rounded, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _hasSnapshot
                                    ? l10n.recoveryRestoreSnapshot
                                    : l10n.recoveryNoSnapshot,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: l10n.recoveryCreateSnapshot,
                        child: OutlinedButton(
                          key: const Key('recovery_create_snapshot_button'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: AppColors.green,
                            side: BorderSide(
                              color: AppColors.green.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isLoading ? null : _createSnapshot,
                          child:
                              const Icon(Icons.bookmark_add_outlined, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Import Backup File
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.file_upload_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.recoveryImportBackup,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Navigate to Backup & Restore screen to inspect and validate external JSON payloads before applying.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: l10n.recoveryImportBackup,
                    child: OutlinedButton.icon(
                      key: const Key('recovery_import_backup_button'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BackupRestoreScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.file_open_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.recoveryImportBackup),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Factory Reset to Demo Data (Explicit Last Resort)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.recoveryFactoryReset,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.factoryResetWarning,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: l10n.recoveryFactoryReset,
                    child: ElevatedButton.icon(
                      key: const Key('recovery_factory_reset_button'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed:
                          _isLoading ? null : _showFactoryResetConfirmation,
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.recoveryFactoryReset),
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
