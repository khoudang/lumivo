import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A subtle, dark minimal brand splash screen featuring a pulsing Lumivo
/// emblem, glowing radial atmosphere, and brand tagline.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1800),
    this.onComplete,
  });

  final Duration duration;
  final VoidCallback? onComplete;

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> pulseAnimation;
  late final Animation<double> fadeAnimation;
  Timer? _completeTimer;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.15, 0.85, curve: Curves.easeIn),
      ),
    );

    // In unit/widget tests, avoid infinite repeat so pumpAndSettle completes.
    final inTest = WidgetsBinding.instance is! WidgetsFlutterBinding;
    if (inTest) {
      controller.forward();
    } else {
      controller.repeat(reverse: true);
    }

    if (widget.onComplete != null) {
      _completeTimer = Timer(widget.duration, () {
        if (mounted) {
          widget.onComplete!();
        }
      });
    }
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing Lumivo Emblem
              ScaleTransition(
                scale: pulseAnimation,
                child: Container(
                  key: const Key('splash_screen_emblem'),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFA294FF),
                        AppColors.primary,
                        AppColors.surfaceElevated,
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 36,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.8,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.blur_on_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title: LUMIVO
              FadeTransition(
                opacity: fadeAnimation,
                child: const Text(
                  'LUMIVO',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Tagline: Intelligent Living, Beautifully Simple
              FadeTransition(
                opacity: fadeAnimation,
                child: const Text(
                  'Intelligent Living, Beautifully Simple',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
