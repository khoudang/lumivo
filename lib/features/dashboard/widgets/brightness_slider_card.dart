import 'package:flutter/material.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

/// An interactive card providing a slider to control the brightness level
/// of a smart light, with a live percentage readout and quick preset shortcuts.
class BrightnessSliderCard extends StatelessWidget {
  const BrightnessSliderCard({
    super.key,
    required this.device,
    required this.brightness,
    required this.onChanged,
    required this.onChangeEnd,
    this.isBusy = false,
  });

  final SmartDevice device;
  final double brightness;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool isBusy;

  bool get _isDisabled =>
      isBusy || device.connection == DeviceConnection.offline;

  @override
  Widget build(BuildContext context) {
    final int percent = brightness.round().clamp(0, 100);
    final bool isLit = percent > 0 && device.isOn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.surfaceBorder.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: AppShadows.cardGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top header row
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLit
                      ? const Color(0xFFE7C184).withValues(alpha: 0.16)
                      : AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLit ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined,
                  color: isLit ? const Color(0xFFE7C184) : AppColors.muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${device.name} Brightness',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.roomId,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isLit
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLit
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isLit ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Slider with Semantics
          Semantics(
            slider: true,
            label: '${device.name} brightness',
            value: '$percent%',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceElevated,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.16),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  pressedElevation: 4,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: brightness.clamp(0.0, 100.0),
                min: 0,
                max: 100,
                onChanged: _isDisabled ? null : onChanged,
                onChangeEnd: _isDisabled ? null : onChangeEnd,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Quick Preset Shortcuts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _presetChip(context, 25),
              _presetChip(context, 50),
              _presetChip(context, 75),
              _presetChip(context, 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(BuildContext context, int targetPercent) {
    final isSelected = brightness.round() == targetPercent;
    return Semantics(
      button: true,
      label: '$targetPercent%',
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _isDisabled
            ? null
            : () {
                final target = targetPercent.toDouble();
                onChanged(target);
                onChangeEnd(target);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.22)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.surfaceBorder,
              width: 1,
            ),
          ),
          child: Text(
            '$targetPercent%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
