import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';

class DemoLabSheet extends ConsumerStatefulWidget {
  const DemoLabSheet({super.key});

  static Future<T?> show<T>(BuildContext context) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const DemoLabSheet(),
    );
  }

  @override
  ConsumerState<DemoLabSheet> createState() => _DemoLabSheetState();
}

class _DemoLabSheetState extends ConsumerState<DemoLabSheet> {
  String? _selectedDeviceId;
  double _packetLoss = 0.0;
  bool _isStormActive = false;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations.fromLanguageCode('en');
    final devicesAsync = ref.watch(devicesProvider);
    final devices = devicesAsync.valueOrNull ?? const [];

    if (devices.isNotEmpty &&
        (_selectedDeviceId == null ||
            !devices.any((d) => d.id == _selectedDeviceId))) {
      _selectedDeviceId = devices.first.id;
    }

    final selectedDevice = devices.cast<SmartDevice?>().firstWhere(
          (d) => d?.id == _selectedDeviceId,
          orElse: () => devices.isNotEmpty ? devices.first : null,
        );

    final isSelectedOffline =
        selectedDevice?.connection == DeviceConnection.offline;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.science_rounded,
                      color: AppColors.cyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.demoLab,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Hardware Fault & Network Chaos Testing',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Section 1: Force Device Offline
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.power_off_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.forceDeviceOffline,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Simulate device hardware disconnect or antenna drop.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (devices.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        key: const Key('fault_device_selector'),
                        initialValue: _selectedDeviceId,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceElevated,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.surfaceBorder),
                          ),
                        ),
                        items: devices
                            .map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    '${d.name} (${d.roomId})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDeviceId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('fault_force_offline_button'),
                          icon: Icon(
                            isSelectedOffline
                                ? Icons.link_rounded
                                : Icons.link_off_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isSelectedOffline
                                ? l10n.reconnectDevice
                                : l10n.forceDeviceOffline,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelectedOffline
                                ? AppColors.green
                                : AppColors.danger,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (selectedDevice == null) return;
                            final repo = ref.read(deviceRepositoryProvider);
                            if (repo is MockDeviceRepository) {
                              repo.toggleDeviceConnection(selectedDevice.id);
                              final willBeOffline = !isSelectedOffline;

                              ref.read(activityProvider.notifier).addEvent(
                                    ActivityEvent(
                                      id: 'act-fault-${DateTime.now().millisecondsSinceEpoch}',
                                      title: willBeOffline
                                          ? 'Fault Injected: ${selectedDevice.name} Offline'
                                          : '${selectedDevice.name} Restored Online',
                                      description: willBeOffline
                                          ? 'Forced offline via Demo Lab fault injection'
                                          : 'Reconnected via Demo Lab',
                                      timestamp: DateTime.now(),
                                      severity: willBeOffline
                                          ? ActivitySeverity.warning
                                          : ActivitySeverity.success,
                                      source: 'demo_lab',
                                    ),
                                  );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    willBeOffline
                                        ? '${selectedDevice.name} forced offline!'
                                        : '${selectedDevice.name} reconnected!',
                                  ),
                                  backgroundColor: willBeOffline
                                      ? AppColors.danger
                                      : AppColors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section 2: Simulate Packet Loss
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.network_ping_rounded,
                          size: 18,
                          color: AppColors.cyan,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.injectPacketLoss,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.cyan.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '${_packetLoss.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Artificially drop telemetry messages and state updates.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      key: const Key('fault_packet_loss_slider'),
                      value: _packetLoss,
                      min: 0.0,
                      max: 100.0,
                      divisions: 20,
                      activeColor: AppColors.cyan,
                      inactiveColor: AppColors.surfaceBorder,
                      onChanged: (val) {
                        setState(() => _packetLoss = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section 3: Trigger Reconnect Storm
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.thunderstorm_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.triggerReconnectStorm,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Simulate gateway reboot causing all nodes to re-authenticate simultaneously.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('fault_reconnect_storm_button'),
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        label: Text(
                          _isStormActive
                              ? 'Simulating Reconnect Storm...'
                              : l10n.triggerReconnectStorm,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          setState(() => _isStormActive = true);

                          ref.read(activityProvider.notifier).addEvent(
                                ActivityEvent(
                                  id: 'act-storm-${DateTime.now().millisecondsSinceEpoch}',
                                  title: 'Chaos: Reconnect Storm Triggered',
                                  description:
                                      'Simulating ${devices.length} devices concurrent MQTT link recovery',
                                  timestamp: DateTime.now(),
                                  severity: ActivitySeverity.warning,
                                  source: 'demo_lab',
                                ),
                              );

                          final repo = ref.read(deviceRepositoryProvider);
                          if (repo is MockDeviceRepository) {
                            for (final d in devices) {
                              if (d.connection == DeviceConnection.offline) {
                                repo.toggleDeviceConnection(d.id);
                              }
                            }
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '⚡ Reconnect Storm triggered! All devices synchronizing...',
                                ),
                                backgroundColor: AppColors.primary,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            setState(() => _isStormActive = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
