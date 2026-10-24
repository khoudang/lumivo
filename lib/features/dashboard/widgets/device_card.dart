import 'package:flutter/material.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

/// A reusable, responsive card representing a smart IoT device with
/// animated state transitions, connection badges, and power controls.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    this.isBusy = false,
    this.onToggle,
    this.onTap,
  });

  final SmartDevice device;
  final bool isBusy;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  bool get _isOffline => device.connection == DeviceConnection.offline;

  IconData _deviceIcon() {
    switch (device.type) {
      case DeviceType.light:
        return device.isOn
            ? Icons.lightbulb_rounded
            : Icons.lightbulb_outline_rounded;
      case DeviceType.fan:
        return Icons.mode_fan_off_outlined;
      case DeviceType.security:
        return device.isOn ? Icons.shield_rounded : Icons.shield_outlined;
      case DeviceType.ac:
        return Icons.ac_unit_rounded;
      case DeviceType.socket:
        return Icons.power_rounded;
      case DeviceType.curtain:
        return Icons.curtains_rounded;
      case DeviceType.lock:
        return device.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded;
      case DeviceType.sensor:
        return Icons.sensors_rounded;
    }
  }

  Color _iconTint() {
    if (_isOffline) return AppColors.mutedDark;
    if (!device.isOn) return AppColors.muted;
    switch (device.type) {
      case DeviceType.light:
        return const Color(0xFFFFD572);
      case DeviceType.fan:
        return AppColors.cyan;
      case DeviceType.security:
        return AppColors.green;
      case DeviceType.ac:
        return AppColors.cyan;
      case DeviceType.socket:
        return AppColors.green;
      case DeviceType.curtain:
        return AppColors.primary;
      case DeviceType.lock:
        return const Color(0xFFFF9E79);
      case DeviceType.sensor:
        return const Color(0xFF72D2FF);
    }
  }

  Gradient _backgroundGradient() {
    if (_isOffline) {
      return const LinearGradient(
        colors: [Color(0xFF141923), Color(0xFF10141D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (!device.isOn) {
      return const LinearGradient(
        colors: [AppColors.surfaceElevated, AppColors.surface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (device.type == DeviceType.security) {
      return AppGradients.activeSecurity;
    }
    return AppGradients.activeCard;
  }

  Border _cardBorder() {
    if (device.isOn && !_isOffline) {
      final borderColor = device.type == DeviceType.security
          ? AppColors.green.withValues(alpha: 0.5)
          : AppColors.primary.withValues(alpha: 0.55);
      return Border.all(color: borderColor, width: 1.2);
    }
    return Border.all(
      color: AppColors.surfaceBorder.withValues(alpha: 0.8),
      width: 1,
    );
  }

  List<BoxShadow> _cardShadow() {
    if (device.isOn && !_isOffline) {
      return [
        BoxShadow(
          color: device.type == DeviceType.security
              ? AppColors.greenGlow.withValues(alpha: 0.25)
              : AppColors.primaryGlow.withValues(alpha: 0.28),
          blurRadius: 20,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return AppShadows.cardGlow;
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText();

    return Semantics(
      button: true,
      label: '${device.name}, $statusText',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: _backgroundGradient(),
          borderRadius: BorderRadius.circular(22),
          border: _cardBorder(),
          boxShadow: _cardShadow(),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: (_isOffline || isBusy) ? null : (onTap ?? onToggle),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row: Icon & Status / Toggle button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon container with soft circular glow
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: device.isOn && !_isOffline
                              ? _iconTint().withValues(alpha: 0.16)
                              : AppColors.surfaceElevated
                                  .withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: device.isOn && !_isOffline
                                ? _iconTint().withValues(alpha: 0.3)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _deviceIcon(),
                          color: _iconTint(),
                          size: 24,
                        ),
                      ),
                      const Spacer(),

                      // Busy spinner or toggle interaction
                      if (isBusy)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        )
                      else if (_isOffline)
                        _offlineBadge()
                      else
                        _powerToggleButton(),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Device Name
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _isOffline
                            ? AppColors.textDisabled
                            : AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Device status subtitle & room
                  Row(
                    children: [
                      if (!_isOffline) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: device.isOn
                                ? AppColors.green
                                : AppColors.mutedDark,
                            shape: BoxShape.circle,
                            boxShadow: device.isOn
                                ? [
                                    BoxShadow(
                                      color: AppColors.greenGlow,
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: _isOffline
                                  ? AppColors.textDisabled
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _powerToggleButton() {
    return Semantics(
      button: true,
      label: '${device.isOn ? 'Turn off' : 'Turn on'} ${device.name}',
      toggled: device.isOn,
      child: GestureDetector(
        key: Key('device_power_btn_${device.id}'),
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Icon(
                device.isOn ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                key: ValueKey<bool>(device.isOn),
                size: 34,
                color: device.isOn ? AppColors.green : AppColors.mutedDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF231C21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 12, color: AppColors.danger),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (_isOffline) return 'Disconnected · ${device.roomId}';
    if (!device.isOn) return 'Off · ${device.roomId}';

    if (device.type == DeviceType.light) {
      return '${device.brightness}% · ${device.roomId}';
    }
    return 'Active · ${device.roomId}';
  }
}
