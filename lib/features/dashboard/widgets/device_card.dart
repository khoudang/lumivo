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

  Color _iconTint(BuildContext context) => device.isOn && !_isOffline
      ? Theme.of(context).colorScheme.primary
      : Theme.of(context).colorScheme.onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText();

    return Semantics(
      button: true,
      label: '${device.name}, $statusText',
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: device.isOn && !_isOffline
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: (_isOffline || isBusy) ? null : (onTap ?? onToggle),
            child: Padding(
              padding: EdgeInsets.all(16),
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
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : Duration(milliseconds: 180),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: device.isOn && !_isOffline
                              ? _iconTint(context).withValues(alpha: 0.16)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: device.isOn && !_isOffline
                                ? _iconTint(context).withValues(alpha: 0.3)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _deviceIcon(),
                          color: _iconTint(context),
                          size: 24,
                        ),
                      ),
                      Spacer(),

                      // Busy spinner or toggle interaction
                      if (isBusy)
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      else if (_isOffline)
                        _offlineBadge(context)
                      else
                        _powerToggleButton(context),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Device Name
                  Text(
                    device.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _isOffline
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.2,
                    ),
                  ),

                  SizedBox(height: 5),

                  // Device status subtitle & room
                  Row(
                    children: [
                      if (!_isOffline) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: device.isOn
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isOffline
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: FontWeight.w500,
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

  Widget _powerToggleButton(BuildContext context) {
    return Semantics(
      button: true,
      label: '${device.isOn ? 'Turn off' : 'Turn on'} ${device.name}',
      toggled: device.isOn,
      child: GestureDetector(
        key: Key('device_power_btn_${device.id}'),
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: Icon(
                device.isOn
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                key: ValueKey<bool>(device.isOn),
                size: 34,
                color: device.isOn
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offlineBadge(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
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
