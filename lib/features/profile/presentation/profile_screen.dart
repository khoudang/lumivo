import 'package:flutter/material.dart';
import '../../../app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../energy/presentation/energy_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _showTariffDialog([AppLocalizations? l10n]) {
    final currentHome = ref.read(currentHomeProvider);
    final currentTariff = ref.read(energyTariffProvider) > 0
        ? ref.read(energyTariffProvider)
        : currentHome.tariffRate;

    final controller =
        TextEditingController(text: currentTariff.toStringAsFixed(3));

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
            Icon(Icons.bolt_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text(
              'Electricity Tariff Setting',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.electricityTariffDesc ??
                  'Set simulated electricity cost rate (\$/kWh):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('profile_tariff_input'),
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '0.160',
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_profile_tariff_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final newRate = double.tryParse(controller.text.trim());
              if (newRate != null && newRate > 0) {
                ref.read(energyTariffProvider.notifier).state = newRate;
                final home = ref.read(currentHomeProvider);
                ref
                    .read(homesProvider.notifier)
                    .updateHome(home.copyWith(tariffRate: newRate));
              }
              Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n?.save ?? 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final profile = ref.watch(userProfileProvider);
    final currentHome = ref.watch(currentHomeProvider);
    final tariffRate = ref.watch(energyTariffProvider) > 0
        ? ref.watch(energyTariffProvider)
        : currentHome.tariffRate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const BackButtonIcon(),
          tooltip: l10n.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.userProfilePreferences),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            // User Profile Card
            _buildProfileCard(profile, l10n),

            const SizedBox(height: 24),

            // Preferences Section
            Text(
              l10n.preferences,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildPreferencesContainer(profile, tariffRate, l10n),

            const SizedBox(height: 24),

            // App Info & Simulation Disclaimer
            _buildDisclaimerCard(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile, [AppLocalizations? l10n]) {
    return Container(
      key: const Key('user_profile_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF221E40), Color(0xFF171D29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: AppShadows.cardGlow,
      ),
      child: Row(
        children: [
          // Avatar Icon with gradient ring
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primary,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    l10n?.homeAdministrator ?? 'Home Administrator',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesContainer(UserProfile profile, double tariffRate,
      [AppLocalizations? l10n]) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Language Preference Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;
                  final titleCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.language ?? 'Language',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        l10n?.systemDisplayLanguage ??
                            'System display language',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  );
                  final pillRow = Wrap(
                    key: const Key('preference_language_selector'),
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _choicePill(
                        label: 'English',
                        isSelected: profile.language == 'en',
                        onTap: () => ref
                            .read(userProfileProvider.notifier)
                            .updateLanguage('en'),
                      ),
                      _choicePill(
                        label: 'Tiếng Việt',
                        isSelected: profile.language == 'vi',
                        onTap: () => ref
                            .read(userProfileProvider.notifier)
                            .updateLanguage('vi'),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.language_rounded,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: titleCol),
                          ],
                        ),
                        const SizedBox(height: 10),
                        pillRow,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const Icon(Icons.language_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: titleCol),
                      pillRow,
                    ],
                  );
                },
              ),
            ),

            const Divider(color: AppColors.surfaceBorder, height: 1),

            // Theme Preference Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;
                  final titleCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.themeMode ?? 'Theme Mode',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        l10n?.themeDescription ??
                            'Dark Minimal vs AMOLED Pure Black',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  );
                  final pillRow = Wrap(
                    key: const Key('preference_theme_toggle'),
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _choicePill(
                        label: 'Dark Minimal',
                        isSelected: profile.themeMode == 'dark',
                        onTap: () => ref
                            .read(userProfileProvider.notifier)
                            .updateTheme('dark'),
                      ),
                      _choicePill(
                        label: 'OLED Black',
                        isSelected: profile.themeMode == 'oled',
                        onTap: () => ref
                            .read(userProfileProvider.notifier)
                            .updateTheme('oled'),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.palette_outlined,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: titleCol),
                          ],
                        ),
                        const SizedBox(height: 10),
                        pillRow,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const Icon(Icons.palette_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: titleCol),
                      pillRow,
                    ],
                  );
                },
              ),
            ),

            const Divider(color: AppColors.surfaceBorder, height: 1),

            // Reduced Motion Switch
            SwitchListTile(
              key: const Key('preference_reduced_motion_switch'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: const Icon(Icons.accessibility_new_rounded,
                  color: AppColors.primary, size: 20),
              title: Text(
                l10n?.reducedMotion ?? 'Reduced Motion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                l10n?.reducedMotionDesc ??
                    'Disables pulse, radar, and shimmer animations for accessibility',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              value: profile.reducedMotion,
              activeThumbColor: AppColors.primary,
              onChanged: (val) =>
                  ref.read(userProfileProvider.notifier).setReducedMotion(val),
            ),

            const Divider(color: AppColors.surfaceBorder, height: 1),

            // Temperature Unit Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;
                  final titleCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.temperatureUnit ?? 'Temperature Unit',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        l10n?.weatherAcDisplay ??
                            'Weather & AC climate display',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  );
                  final pillRow = Wrap(
                    key: const Key('preference_temp_unit_selector'),
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _choicePill(
                        label: 'Celsius (°C)',
                        isSelected: profile.temperatureUnit == 'C',
                        onTap: () => ref
                            .read(userProfileProvider.notifier)
                            .updateTemperatureUnit('C'),
                      ),
                      _choicePill(
                        label: 'Fahrenheit (°F)',
                        isSelected: profile.temperatureUnit == 'F',
                        onTap: () => ref
                            .read(userProfileProvider.notifier)
                            .updateTemperatureUnit('F'),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.thermostat_outlined,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: titleCol),
                          ],
                        ),
                        const SizedBox(height: 10),
                        pillRow,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const Icon(Icons.thermostat_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: titleCol),
                      pillRow,
                    ],
                  );
                },
              ),
            ),

            const Divider(color: AppColors.surfaceBorder, height: 1),

            // Electricity Tariff Dialog Tile
            ListTile(
              key: const Key('preference_tariff_tile'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 20),
              title: Text(
                l10n?.electricityTariff ?? 'Electricity Tariff',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                '\$${tariffRate.toStringAsFixed(3)} / kWh (${l10n?.simulated ?? "Simulated"})',
                style: const TextStyle(fontSize: 11, color: AppColors.cyan),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.muted),
              onTap: () => _showTariffDialog(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choicePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                width: isSelected ? 1.2 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard([AppLocalizations? l10n]) {
    return Container(
      key: const Key('profile_simulation_disclaimer'),
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
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.simulationDisclosure ?? 'Simulation Mode Disclosure',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.simulationModeDesc ??
                'All simulated telemetry, device states, energy consumption, and scheduled automations run locally on virtual simulated state machines. Designed for Dark Minimal smart home operation.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Version 1.0.0 (Distribution Release) • 100% Offline Simulation',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
