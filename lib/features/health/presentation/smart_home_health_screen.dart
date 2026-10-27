import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';

enum DeviceHealthFilter { all, online, degraded, offline }

class SmartHomeHealthScreen extends ConsumerStatefulWidget {
  const SmartHomeHealthScreen({super.key});

  @override
  ConsumerState<SmartHomeHealthScreen> createState() =>
      _SmartHomeHealthScreenState();
}

class _SmartHomeHealthScreenState extends ConsumerState<SmartHomeHealthScreen> {
  DeviceHealthFilter _currentFilter = DeviceHealthFilter.all;

  int _getDeviceRssi(SmartDevice device) {
    if (device.customData['rssi'] is num) {
      return (device.customData['rssi'] as num).toInt();
    }
    // Realistic deterministic simulated RSSI based on id hash
    final offset = (device.id.hashCode.abs() % 35);
    return -50 - offset;
  }

  int? _getDeviceBattery(SmartDevice device) {
    if (device.customData['battery'] is num) {
      return (device.customData['battery'] as num).toInt();
    }
    if (device.type == DeviceType.lock) return 78;
    if (device.type == DeviceType.sensor) return 92;
    if (device.type == DeviceType.security) return 65;
    return null;
  }

  bool _isDeviceDegraded(SmartDevice device) {
    final isOffline = device.connection == DeviceConnection.offline;
    if (isOffline) return false;
    final rssi = _getDeviceRssi(device);
    final battery = _getDeviceBattery(device);
    return rssi < -80 || (battery != null && battery < 20);
  }

  int _calculateHealthScore(List<SmartDevice> devices) {
    if (devices.isEmpty) return 100;
    final total = devices.length;
    final onlineCount =
        devices.where((d) => d.connection == DeviceConnection.online).length;
    final degradedCount = devices.where(_isDeviceDegraded).length;

    double score = (onlineCount / total) * 100.0;
    score -= (degradedCount * 5.0);
    return score.clamp(0.0, 100.0).round();
  }

  List<String> _collectWarnings(
      List<SmartDevice> devices, AppLocalizations l10n) {
    final warnings = <String>[];
    for (final d in devices) {
      if (d.connection == DeviceConnection.offline) {
        warnings.add('${d.name} (${d.roomId}): ${l10n.offline}');
      } else {
        final rssi = _getDeviceRssi(d);
        if (rssi < -80) {
          warnings.add(
              '${d.name}: Weak Wi-Fi signal ($rssi dBm). Relocate nearer to router.');
        }
        final battery = _getDeviceBattery(d);
        if (battery != null && battery < 20) {
          warnings.add('${d.name}: Low battery ($battery%). Replace soon.');
        }
      }
    }
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations.fromLanguageCode('en');
    final devicesAsync = ref.watch(devicesProvider);
    final allDevices = devicesAsync.valueOrNull ?? const [];

    final healthScore = _calculateHealthScore(allDevices);
    final onlineDevices = allDevices
        .where((d) => d.connection == DeviceConnection.online)
        .toList();
    final offlineDevices = allDevices
        .where((d) => d.connection == DeviceConnection.offline)
        .toList();
    final degradedDevices = allDevices.where(_isDeviceDegraded).toList();
    final warnings = _collectWarnings(allDevices, l10n);

    final filteredDevices = allDevices.where((d) {
      switch (_currentFilter) {
        case DeviceHealthFilter.all:
          return true;
        case DeviceHealthFilter.online:
          return d.connection == DeviceConnection.online;
        case DeviceHealthFilter.degraded:
          return _isDeviceDegraded(d);
        case DeviceHealthFilter.offline:
          return d.connection == DeviceConnection.offline;
      }
    }).toList();

    return Scaffold(
      key: const Key('smart_home_health_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.healthDashboard,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Simulation Disclosure Banner
            Container(
              key: const Key('health_simulation_disclosure_badge'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.offline_bolt_rounded,
                      color: AppColors.cyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.simulationModeDesc,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section 1: Health Score Dial
            _buildHealthDialSection(healthScore, l10n),

            const SizedBox(height: 20),

            // Section 2: Count Cards (Online, Offline, Degraded)
            _buildCountCards(
              onlineCount: onlineDevices.length,
              offlineCount: offlineDevices.length,
              degradedCount: degradedDevices.length,
              l10n: l10n,
            ),

            const SizedBox(height: 24),

            // Section 3: Active Warnings
            _buildActiveWarningsSection(warnings, l10n),

            const SizedBox(height: 24),

            // Section 4: Filterable Devices
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.devices,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${filteredDevices.length} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _filterChip(
                    label: l10n.all,
                    count: allDevices.length,
                    selected: _currentFilter == DeviceHealthFilter.all,
                    onSelected: () =>
                        setState(() => _currentFilter = DeviceHealthFilter.all),
                  ),
                  _filterChip(
                    label: l10n.devicesOnline,
                    count: onlineDevices.length,
                    selected: _currentFilter == DeviceHealthFilter.online,
                    onSelected: () => setState(
                        () => _currentFilter = DeviceHealthFilter.online),
                  ),
                  _filterChip(
                    label: l10n.healthDegraded,
                    count: degradedDevices.length,
                    selected: _currentFilter == DeviceHealthFilter.degraded,
                    onSelected: () => setState(
                        () => _currentFilter = DeviceHealthFilter.degraded),
                  ),
                  _filterChip(
                    label: l10n.offline,
                    count: offlineDevices.length,
                    selected: _currentFilter == DeviceHealthFilter.offline,
                    onSelected: () => setState(
                        () => _currentFilter = DeviceHealthFilter.offline),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Device Items
            for (final device in filteredDevices) ...[
              _buildDeviceHealthCard(device, l10n),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthDialSection(int score, AppLocalizations l10n) {
    Color dialColor;
    String statusText;

    if (score >= 85) {
      dialColor = AppColors.green;
      statusText = l10n.healthOptimal;
    } else if (score >= 60) {
      dialColor = AppColors.warning;
      statusText = l10n.healthDegraded;
    } else {
      dialColor = AppColors.danger;
      statusText = l10n.healthOfflineWarning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dialColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: dialColor.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(150, 150),
                  painter: _HealthScoreDialPainter(
                    score: score,
                    dialColor: dialColor,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: dialColor,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: dialColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: dialColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: dialColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.systemHealthScore,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Continuous monitoring of mesh connectivity, latency & RSSI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCards({
    required int onlineCount,
    required int offlineCount,
    required int degradedCount,
    required AppLocalizations l10n,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _countCard(
              title: l10n.devicesOnline,
              count: '$onlineCount',
              icon: Icons.check_circle_rounded,
              color: AppColors.green,
              width: constraints.maxWidth < 360
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3,
            ),
            _countCard(
              title: l10n.devicesOffline,
              count: '$offlineCount',
              icon: Icons.cloud_off_rounded,
              color: AppColors.danger,
              width: constraints.maxWidth < 360
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3,
            ),
            _countCard(
              title: l10n.healthDegraded,
              count: '$degradedCount',
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              width: constraints.maxWidth < 360
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 20) / 3,
            ),
          ],
        );
      },
    );
  }

  Widget _countCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Text(
                count,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWarningsSection(
      List<String> warnings, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: warnings.isEmpty
              ? AppColors.green.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                warnings.isEmpty
                    ? Icons.verified_rounded
                    : Icons.warning_rounded,
                size: 20,
                color: warnings.isEmpty ? AppColors.green : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.activeWarnings,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (warnings.isEmpty ? AppColors.green : AppColors.warning)
                          .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${warnings.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        warnings.isEmpty ? AppColors.green : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (warnings.isEmpty)
            Text(
              l10n.noWarnings,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.green,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            ...warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4, right: 8),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.warning,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        w,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary.withValues(alpha: 0.28),
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.muted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDeviceHealthCard(SmartDevice device, AppLocalizations l10n) {
    final isOnline = device.connection == DeviceConnection.online;
    final isDegraded = _isDeviceDegraded(device);
    final rssi = _getDeviceRssi(device);
    final battery = _getDeviceBattery(device);

    Color badgeColor;
    String badgeText;
    if (!isOnline) {
      badgeColor = AppColors.danger;
      badgeText = l10n.offline;
    } else if (isDegraded) {
      badgeColor = AppColors.warning;
      badgeText = l10n.healthDegraded;
    } else {
      badgeColor = AppColors.green;
      badgeText = 'Online';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
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
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _deviceTypeIcon(device.type),
                  color: badgeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.roomId,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Metrics & Reconnect Action Row
          Row(
            children: [
              // RSSI Signal Strength
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.signal_cellular_alt_rounded,
                    size: 14,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$rssi dBm',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (battery != null) ...[
                const SizedBox(width: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      battery < 20
                          ? Icons.battery_alert_rounded
                          : Icons.battery_charging_full_rounded,
                      size: 14,
                      color: battery < 20 ? AppColors.danger : AppColors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$battery%',
                      style: TextStyle(
                        fontSize: 11,
                        color: battery < 20
                            ? AppColors.danger
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              // Quick Reconnect Button with minimum 48x48 pt touch target
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  key: Key('reconnect_device_${device.id}'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    l10n.reconnectDevice,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    final repo = ref.read(deviceRepositoryProvider);
                    if (repo is MockDeviceRepository) {
                      if (device.connection == DeviceConnection.offline) {
                        repo.toggleDeviceConnection(device.id);
                      }
                      ref.read(activityProvider.notifier).addEvent(
                            ActivityEvent(
                              id: 'act-recon-${DateTime.now().millisecondsSinceEpoch}',
                              title: 'Quick Reconnect: ${device.name}',
                              description:
                                  'Handshake re-established via Health Screen',
                              timestamp: DateTime.now(),
                              severity: ActivitySeverity.info,
                              source: 'health_dashboard',
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${device.name} reconnected successfully!'),
                          backgroundColor: AppColors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _deviceTypeIcon(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return Icons.lightbulb_outline_rounded;
      case DeviceType.fan:
        return Icons.mode_fan_off_outlined;
      case DeviceType.security:
        return Icons.shield_outlined;
      case DeviceType.ac:
        return Icons.ac_unit_rounded;
      case DeviceType.socket:
        return Icons.power_rounded;
      case DeviceType.curtain:
        return Icons.curtains_rounded;
      case DeviceType.lock:
        return Icons.lock_rounded;
      case DeviceType.sensor:
        return Icons.sensors_rounded;
    }
  }
}

class _HealthScoreDialPainter extends CustomPainter {
  const _HealthScoreDialPainter({
    required this.score,
    required this.dialColor,
  });

  final int score;
  final Color dialColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = AppColors.surfaceElevated
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Active progress arc
    final sweepAngle = (score / 100.0) * math.pi * 1.5;
    final progressPaint = Paint()
      ..color = dialColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthScoreDialPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.dialColor != dialColor;
}
