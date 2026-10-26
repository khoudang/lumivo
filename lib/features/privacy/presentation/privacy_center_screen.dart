import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/backup_payload.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../automation/state/automation_providers.dart';
import 'recovery_center_screen.dart';

class PrivacyCenterScreen extends ConsumerStatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  ConsumerState<PrivacyCenterScreen> createState() =>
      _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends ConsumerState<PrivacyCenterScreen> {
  void _exportBackup() {
    final currentHome = ref.read(currentHomeProvider);
    final homes = ref.read(homesProvider).homes;
    final effectiveHomes = homes.isNotEmpty ? homes : [currentHome];
    final rooms = ref.read(roomsProvider);
    final devices = ref.read(devicesProvider).valueOrNull ?? [];
    final scenes = ref.read(scenesProvider);
    final automations = ref.read(automationRulesProvider);

    final payload = BackupPayload(
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

  void _showResetDemoConfirmation() {
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
                l10n.resetDemoData,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This will revert all devices, rooms, automations, scenes, activity logs and notifications to their initial factory demo states.',
          style: TextStyle(
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
            label: l10n.resetDemoData,
            child: ElevatedButton(
              key: const Key('confirm_reset_demo_button'),
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

                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Demo environment reset to factory defaults'),
                      backgroundColor: AppColors.green,
                    ),
                  );
                }
              },
              child: Text(l10n.resetDemoData),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearActivityConfirmation() {
    final l10n = ref.read(appLocalizationsProvider);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.warning, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.history_toggle_off_rounded,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.clearActivityHistory,
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
          l10n.confirmClearHistoryBody,
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
            label: l10n.delete,
            child: ElevatedButton(
              key: const Key('confirm_clear_history_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 48),
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                ref.read(activityProvider.notifier).clearEvents();
                Navigator.of(dialogCtx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.historyCleared),
                    backgroundColor: AppColors.green,
                  ),
                );
              },
              child: Text(l10n.delete),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearNotificationsConfirmation() {
    final l10n = ref.read(appLocalizationsProvider);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.warning, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications_off_outlined,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.clearNotifications,
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
          l10n.confirmClearNotificationsBody,
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
            label: l10n.delete,
            child: ElevatedButton(
              key: const Key('confirm_clear_notifications_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 48),
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                ref.read(notificationsProvider.notifier).clearAll();
                Navigator.of(dialogCtx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.notificationsCleared),
                    backgroundColor: AppColors.green,
                  ),
                );
              },
              child: Text(l10n.delete),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final persistence = ref.watch(homePersistenceProvider);
    final homeState = persistence.cachedState ?? persistence.createDemoState();

    // Data usage calculation
    final usageBytes = persistence.getApproximateStorageSizeBytes(homeState);
    final usageKb = (usageBytes / 1024.0).toStringAsFixed(1);

    // Last save metadata
    final lastSaved = persistence.lastSavedAt;
    final lastSavedText = lastSaved != null
        ? '${lastSaved.hour.toString().padLeft(2, '0')}:${lastSaved.minute.toString().padLeft(2, '0')}:${lastSaved.second.toString().padLeft(2, '0')}'
        : 'Recently';

    // Category counts breakdown
    final homesCount = homeState.homes.isNotEmpty ? homeState.homes.length : 1;
    final roomsCount = homeState.rooms.length;
    final devicesCount = homeState.devices.length;
    final automationsCount = homeState.automations.length;
    final scenesCount = homeState.scenes.length;
    final eventsCount = ref.watch(activityProvider).length;
    final notifsCount = ref.watch(notificationsProvider).length;
    final configsCount = homeState.dashboardConfigs.length;
    final telemetryCount = homeState.energySamples.length;

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
            l10n.privacyCenter,
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
            // 1. Simulation Mode Status Card (100% offline, no cloud backend, no physical hardware)
            Container(
              key: const Key('privacy_simulation_mode_card'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF192A28), Color(0xFF141923)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.35),
                  width: 1.2,
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
                          color: AppColors.green.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: AppColors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    l10n.simulationModeStatus,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.green,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '100% OFFLINE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'No cloud backend · No physical hardware connection',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lumivo is operating strictly offline with local virtual state machines. No telemetry, audio, credentials, or personal device identifiers are transmitted outside your device.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Health & Storage Usage Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            key: const Key(
                                'privacy_persistence_health_indicator'),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded,
                                color: AppColors.green, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.storageHealth,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                l10n.storageHealthOptimal,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.storageUsageApprox,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            key: const Key('privacy_storage_usage_text'),
                            '$usageKb KB',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.surfaceBorder, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.lastSavedTime,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        key: const Key('privacy_last_save_metadata'),
                        'Today at $lastSavedText',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. Local Data Storage Explanation & 9 Categories Breakdown
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_special_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.localStorageTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.localStorageDesc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.storageCategories.toUpperCase(),
                    style: const TextStyle(
                      letterSpacing: 1.2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 9 Categories Breakdown Grid
                  _categoryRow(
                      'Homes', '$homesCount homes', Icons.home_rounded),
                  _categoryRow(
                      'Rooms', '$roomsCount rooms', Icons.meeting_room_rounded),
                  _categoryRow('Devices', '$devicesCount devices',
                      Icons.devices_other_rounded),
                  _categoryRow('Automations', '$automationsCount rules',
                      Icons.smart_toy_rounded),
                  _categoryRow(
                      'Scenes', '$scenesCount scenes', Icons.palette_rounded),
                  _categoryRow('Activity History', '$eventsCount log events',
                      Icons.receipt_long_rounded),
                  _categoryRow(
                      'In-App Notifications',
                      '$notifsCount notifications',
                      Icons.notifications_active_rounded),
                  _categoryRow('Dashboard Configs', '$configsCount layouts',
                      Icons.dashboard_customize_rounded),
                  _categoryRow('Energy Telemetry', '$telemetryCount samples',
                      Icons.bolt_rounded),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Quick Actions Section
            const Text(
              'PRIVACY & RECOVERY CONTROLS',
              style: TextStyle(
                letterSpacing: 1.5,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Export Backup Button
            Semantics(
              button: true,
              label: l10n.exportBackup,
              child: ElevatedButton.icon(
                key: const Key('privacy_export_backup_button'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _exportBackup,
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.exportBackup),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Open Recovery Center Button
            Semantics(
              button: true,
              label: l10n.openRecoveryCenter,
              child: OutlinedButton.icon(
                key: const Key('privacy_open_recovery_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.cyan,
                  side: BorderSide(
                    color: AppColors.cyan.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RecoveryCenterScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.healing_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.openRecoveryCenter),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Clear Activity History
            Semantics(
              button: true,
              label: l10n.clearActivityHistory,
              child: OutlinedButton.icon(
                key: const Key('privacy_clear_activity_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.warning,
                  side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _showClearActivityConfirmation,
                icon: const Icon(Icons.history_toggle_off_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.clearActivityHistory),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Clear Notifications
            Semantics(
              button: true,
              label: l10n.clearNotifications,
              child: OutlinedButton.icon(
                key: const Key('privacy_clear_notifications_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.warning,
                  side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _showClearNotificationsConfirmation,
                icon: const Icon(Icons.notifications_off_outlined, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.clearNotifications),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Reset Demo Data
            Semantics(
              button: true,
              label: l10n.resetDemoData,
              child: OutlinedButton.icon(
                key: const Key('privacy_reset_demo_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _showResetDemoConfirmation,
                icon: const Icon(Icons.restore_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.resetDemoData),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(String title, String count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
