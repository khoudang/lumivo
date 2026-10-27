import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/in_app_notification.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../state/demo_lab_providers.dart';

class DemoLabScreen extends ConsumerWidget {
  const DemoLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labState = ref.watch(demoLabProvider);
    final labNotifier = ref.read(demoLabProvider.notifier);
    final l10n = ref.watch(appLocalizationsProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final devices = devicesAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Demo Lab & Chaos Sim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Section 1: Virtual Clock
            _buildSectionCard(
              title: 'Virtual Simulation Clock',
              icon: Icons.access_time_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT VIRTUAL TIME',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatVirtualTime(labState.virtualTime),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${labState.speedMultiplier}x Speed',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Speed Multiplier',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 10, 60, 300].map((mult) {
                      final isSelected = labState.speedMultiplier == mult;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ElevatedButton(
                            key: Key('speed_${mult}x'),
                            onPressed: () =>
                                labNotifier.setSpeedMultiplier(mult),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceElevated,
                              foregroundColor: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceBorder,
                                ),
                              ),
                            ),
                            child: Text(
                              '${mult}x',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.fastForwardJump,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('advance_1_hour_button'),
                        icon: const Icon(Icons.fast_forward_rounded, size: 16),
                        label: Text(l10n.advance1Hour),
                        onPressed: () => labNotifier.advanceHour(),
                      ),
                      OutlinedButton.icon(
                        key: const Key('jump_0700_button'),
                        icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                        label: Text(l10n.jumpTo0700),
                        onPressed: () => labNotifier.jumpToTime(7, 0),
                      ),
                      OutlinedButton.icon(
                        key: const Key('jump_2200_button'),
                        icon: const Icon(Icons.nights_stay_rounded, size: 16),
                        label: Text(l10n.jumpTo2200),
                        onPressed: () => labNotifier.jumpToTime(22, 0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 2: Ambient Environment Controls
            _buildSectionCard(
              title: 'Ambient Environment Controls',
              icon: Icons.cloud_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.ambientTemp,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${labState.ambientTemperature.toStringAsFixed(1)} °C',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('ambient_temp_slider'),
                    value: labState.ambientTemperature,
                    min: 10.0,
                    max: 40.0,
                    onChanged: (val) => labNotifier.setAmbientTemperature(val),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Ambient Humidity',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${labState.ambientHumidity.toStringAsFixed(0)} %',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('ambient_humidity_slider'),
                    value: labState.ambientHumidity,
                    min: 20.0,
                    max: 95.0,
                    onChanged: (val) => labNotifier.setAmbientHumidity(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 3: Chaos Testing
            _buildSectionCard(
              title: 'Chaos & Fault Injection',
              icon: Icons.electric_bolt_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MQTT Network Drop
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: labState.isMqttConnected
                                ? AppColors.green.withValues(alpha: 0.15)
                                : AppColors.danger.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            labState.isMqttConnected
                                ? Icons.wifi_rounded
                                : Icons.wifi_off_rounded,
                            color: labState.isMqttConnected
                                ? AppColors.green
                                : AppColors.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                labState.isMqttConnected
                                    ? 'MQTT Network Connected'
                                    : 'MQTT Network Dropped',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                labState.isMqttConnected
                                    ? 'Broker latency: 12ms · Active'
                                    : 'Simulating broker disconnect',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          key: const Key('toggle_mqtt_button'),
                          onPressed: () {
                            labNotifier.toggleMqttConnection();
                            final isNowConnected = !labState.isMqttConnected;

                            ref.read(activityProvider.notifier).addEvent(
                                  ActivityEvent(
                                    id: 'act-${DateTime.now().millisecondsSinceEpoch}',
                                    title: isNowConnected
                                        ? 'MQTT Reconnected'
                                        : 'Simulated MQTT Network Drop',
                                    description: isNowConnected
                                        ? 'Broker connection restored'
                                        : 'Network drop injected in Demo Lab',
                                    timestamp: DateTime.now(),
                                    severity: isNowConnected
                                        ? ActivitySeverity.success
                                        : ActivitySeverity.alert,
                                    source: 'simulation',
                                  ),
                                );

                            if (!isNowConnected) {
                              ref
                                  .read(notificationsProvider.notifier)
                                  .addNotification(
                                    InAppNotification(
                                      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
                                      title: 'MQTT Network Drop Injected',
                                      body:
                                          'All live telemetry streams suspended.',
                                      timestamp: DateTime.now(),
                                      severity: ActivitySeverity.alert,
                                    ),
                                  );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: labState.isMqttConnected
                                ? AppColors.danger
                                : AppColors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            labState.isMqttConnected ? 'Drop' : 'Restore',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Device Online / Offline Toggles',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final device in devices) ...[
                    _buildDeviceChaosRow(context, ref, device),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceChaosRow(
    BuildContext context,
    WidgetRef ref,
    SmartDevice device,
  ) {
    final isOnline = device.connection == DeviceConnection.online;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.link_rounded : Icons.link_off_rounded,
            color: isOnline ? AppColors.green : AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  device.roomId,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: Key('toggle_device_online_${device.id}'),
            value: isOnline,
            activeThumbColor: AppColors.green,
            inactiveThumbColor: AppColors.danger,
            onChanged: (_) {
              final repo = ref.read(deviceRepositoryProvider);
              if (repo is MockDeviceRepository) {
                repo.toggleDeviceConnection(device.id);

                ref.read(activityProvider.notifier).addEvent(
                      ActivityEvent(
                        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
                        title:
                            '${device.name} ${isOnline ? "went Offline" : "came Online"}',
                        description: 'Simulated connection state change',
                        timestamp: DateTime.now(),
                        deviceId: device.id,
                        roomId: device.roomId,
                        severity: isOnline
                            ? ActivitySeverity.warning
                            : ActivitySeverity.success,
                        source: 'simulation',
                      ),
                    );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
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
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _formatVirtualTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}
