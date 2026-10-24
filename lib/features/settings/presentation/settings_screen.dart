import '../../backup/presentation/backup_restore_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../energy/presentation/energy_screen.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../automation/state/automation_providers.dart';
import '../../demo_lab/presentation/demo_lab_screen.dart';
import '../../demo_lab/state/demo_lab_providers.dart';
import '../../onboarding/presentation/welcome_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedAccent = 'Lumivo Violet';
  bool _oledDark = false;

  void _showResetConfirmation([AppLocalizations? l10n]) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 10),
            Text(l10n != null ? '${l10n.resetDemoData}?' : 'Reset Demo Data?'),
          ],
        ),
        content: const Text(
          'This will revert all devices, rooms, automations, activity logs and notifications to their initial Phase 2 factory demo states.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_reset_demo_data_button'),
            onPressed: () {
              // Reset repositories and notifiers
              final repo = ref.read(deviceRepositoryProvider);
              if (repo is MockDeviceRepository) {
                repo.resetToDefaults();
              }
              ref.read(roomsProvider.notifier).reset();
              ref.read(automationRulesProvider.notifier).reset();
              ref.read(activityProvider.notifier).reset();
              ref.read(notificationsProvider.notifier).reset();
              ref.read(demoLabProvider.notifier).reset();

              Navigator.of(dialogCtx).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo environment reset to factory defaults'),
                  backgroundColor: AppColors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n?.resetAll ?? 'Reset All'),
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM & PREFERENCES',
                  style: TextStyle(
                    letterSpacing: 1.5,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.settings,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Demo Lab Navigation Tile (Prominent)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF26214B), Color(0xFF171D29)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: AppShadows.cardGlow,
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  key: const Key('open_demo_lab_tile'),
                  contentPadding: const EdgeInsets.all(18),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.science_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  title: Text(
                    'Demo Lab & Chaos Sim',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Virtual clock, ambient sensors & network drop injection',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DemoLabScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Profile & Energy Intelligence
            _buildSection(
              title: 'Consumer Experience & Intelligence',
              icon: Icons.auto_graph_rounded,
              children: [
                ListTile(
                  key: const Key('open_profile_screen_tile'),
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'User Profile & Preferences',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Language, theme mode, accessibility & tariffs',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                const Divider(color: AppColors.surfaceBorder, height: 16),
                ListTile(
                  key: const Key('open_energy_screen_tile'),
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.green,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Energy Telemetry & Analytics',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Virtual consumption, device breakdown & cost projections',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EnergyScreen()),
                    );
                  },
                ),
                const Divider(color: AppColors.surfaceBorder, height: 16),
                ListTile(
                  key: const Key('settings_backup_tile'),
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB388FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_backup_restore_rounded,
                      color: Color(0xFFB388FF),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    l10n.backupAndRestore,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Export JSON snapshots & restore smart home configuration',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BackupRestoreScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: AppColors.surfaceBorder, height: 16),
                ListTile(
                  key: const Key('open_welcome_tour_tile'),
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      color: AppColors.cyan,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Welcome & Demo Tour',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Revisit onboarding highlights, simulation guide & offline mode',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WelcomeScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Theme Customization
            _buildSection(
              title: l10n.aestheticsTheme,
              icon: Icons.palette_outlined,
              children: [
                Text(
                  'Accent Hue',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Lumivo Violet',
                    'Neon Cyan',
                    'Emerald Mint',
                    'Solar Amber'
                  ].map((color) {
                    final isSelected = _selectedAccent == color;
                    return ChoiceChip(
                      label: Text(color),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.25),
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedAccent = color);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.oledPureBlackTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Optimized for battery saving on AMOLED displays',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  value: _oledDark,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _oledDark = val),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Simulation Mode Disclosure
            _buildSection(
              title: 'Simulation Mode Disclosure',
              icon: Icons.info_outline_rounded,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.green, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Mock Hardware Simulation Active',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Lumivo is running against internal memory-backed state machines for simulated BLE provisioning, MQTT telemetry, and virtual environmental sensors. No real radio hardware required.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // App Info
            _buildSection(
              title: 'About Lumivo',
              icon: Icons.apps_rounded,
              children: [
                _infoTile('Version', '2.0.0-phase2 (Build 2026.10)'),
                _infoTile('Framework', 'Flutter 3.24+ / Riverpod 2.6'),
                _infoTile('Architecture', 'Dark Minimal Consumer IoT UX'),
                _infoTile('Workspace', 'D:\\app_iot\\lumivo_phase2_ui'),
              ],
            ),
            const SizedBox(height: 24),

            // Reset Demo Data Button
            OutlinedButton.icon(
              key: const Key('reset_demo_data_button'),
              icon: const Icon(Icons.restore_rounded,
                  color: AppColors.danger, size: 20),
              label: Text(
                l10n.resetDemoData,
                style: TextStyle(color: AppColors.danger),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _showResetConfirmation(l10n),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
