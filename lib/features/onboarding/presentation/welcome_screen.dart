import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../profile/state/user_profile_notifier.dart';
import '../state/first_run_notifier.dart';

/// A consumer-friendly, dark minimal first-run welcome experience for Lumivo.
///
/// Features glowing Lumivo branding, swipeable IoT capability cards,
/// an offline demo mode disclosure, and navigation into the main Dashboard.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({
    super.key,
    this.onCompleted,
  });

  final VoidCallback? onCompleted;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleEnterDashboard() async {
    await ref.read(firstRunCompletedProvider.notifier).completeFirstRun();
    widget.onCompleted?.call();

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isReduced = ref.watch(userProfileProvider).reducedMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    final features = [
      _FeatureHighlight(
        title: l10n?.featureIotSimTitle ?? 'Deterministic IoT Simulation',
        subtitle: l10n?.featureIotSimSubtitle ??
            'Bulbs, fans, climate AC, sockets, curtains, smart locks & environment sensors.',
        icon: Icons.tune_rounded,
        accentColor: AppColors.primary,
        tag: l10n?.featureIotSimTag ?? 'SIMULATED HARDWARE',
      ),
      _FeatureHighlight(
        title: l10n?.featureAmbianceTitle ?? 'Ambiance & Automated Routines',
        subtitle: l10n?.featureAmbianceSubtitle ??
            'One-tap scenes, schedule-based triggers & threshold sensor automations.',
        icon: Icons.auto_awesome_rounded,
        accentColor: AppColors.cyan,
        tag: l10n?.featureAmbianceTag ?? 'SMART ORCHESTRATION',
      ),
      _FeatureHighlight(
        title: l10n?.featureEnergyTitle ?? 'Simulated Energy Telemetry',
        subtitle: l10n?.featureEnergySubtitle ??
            'Live wattage consumption, historical telemetry & configurable tariffs.',
        icon: Icons.bolt_rounded,
        accentColor: AppColors.green,
        tag: l10n?.featureEnergyTag ?? 'POWER ANALYTICS',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final horizontalPadding = screenWidth < 360 ? 14.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),

                  // Lumivo Glowing Emblem
                  _buildGlowingEmblem(),

                  const SizedBox(height: 16),

                  // Brand Titles
                  const Text(
                    'LUMIVO Smart Home',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.brandTagline ??
                        'Intelligent Living, Beautifully Simple',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Swipeable Feature Highlights
                  _buildFeatureCarousel(features),

                  const SizedBox(height: 12),

                  // Carousel Page Indicator Dots
                  _buildPageIndicators(features.length, isReduced),

                  const SizedBox(height: 18),

                  // Prominent Demo Mode & Offline Smart Home Callout
                  _buildDemoModeBadge(l10n),

                  const SizedBox(height: 20),

                  // Primary Action: Enter Demo Mode
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('enter_demo_mode_button'),
                      onPressed: _handleEnterDashboard,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n?.enterDemoMode ?? 'Enter Demo Mode',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Secondary Action: Skip to Dashboard
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      key: const Key('skip_welcome_button'),
                      onPressed: _handleEnterDashboard,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n?.skipToDashboard ?? 'Skip to Dashboard',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlowingEmblem() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF9E91FF),
            AppColors.primary,
            AppColors.surfaceElevated,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.blur_on_rounded,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildFeatureCarousel(List<_FeatureHighlight> features) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final carouselHeight =
        (200.0 * textScale.clamp(1.0, 1.8)).clamp(200.0, 320.0);

    return SizedBox(
      height: carouselHeight,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _currentPage = idx),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: feature.accentColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: feature.accentColor.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: feature.accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: feature.accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          feature.icon,
                          color: feature.accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            feature.tag,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: feature.accentColor,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicators(int count, bool isReduced) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) {
          final isSelected = index == _currentPage;
          return Semantics(
            button: true,
            selected: isSelected,
            label: 'Page ${index + 1}',
            child: GestureDetector(
              key: Key('welcome_indicator_$index'),
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: isReduced
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: isReduced
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDemoModeBadge(AppLocalizations? l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF221A3E), Color(0xFF151C2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.offline_bolt_rounded,
            color: AppColors.cyan,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n?.demoModeCallout ??
                  '✦ DEMO MODE • 100% OFFLINE SMART HOME — No hardware, cloud login, or external network required.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHighlight {
  const _FeatureHighlight({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.tag,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String tag;
}
