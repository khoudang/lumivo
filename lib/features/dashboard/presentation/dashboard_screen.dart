import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../onboarding/presentation/add_device_sheet.dart';
import '../widgets/brightness_slider_card.dart';
import '../widgets/device_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/room_selector.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String room = 'Living Room';
  int selectedTab = 0;
  final Set<String> pending = {};
  int serial = 0;
  final Map<String, double> brightnessDraft = {};

  Future<void> _send(
    SmartDevice device,
    DeviceCommandType type,
    Object value,
  ) async {
    if (pending.contains(device.id)) return;
    setState(() => pending.add(device.id));

    final result = await ref.read(deviceRepositoryProvider).sendCommand(
          DeviceCommand(
            requestId: 'local-${++serial}',
            deviceId: device.id,
            type: type,
            value: value,
          ),
        );

    if (!mounted) return;
    setState(() => pending.remove(device.id));

    if (result.status != CommandStatus.confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Command failed'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _openAddDeviceSheet() {
    AddDeviceSheet.show(
      context,
      onDeviceAdded: (newDevice) {
        final repo = ref.read(deviceRepositoryProvider);
        if (repo is MockDeviceRepository) {
          repo.addDevice(newDevice);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newDevice.name} paired successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      floatingActionButton: selectedTab == 0
          ? FloatingActionButton(
              onPressed: _openAddDeviceSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Add Device',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                Expanded(
                  child: selectedTab == 0
                      ? devices.when(
                          data: (all) => _home(all),
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, _) => Center(
                            child: Text(
                              'Error: $error',
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ),
                        )
                      : _placeholderTab(),
                ),
                _navigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _home(List<SmartDevice> all) {
    const rooms = ['Living Room', 'Bedroom', 'Kitchen'];

    final roomCounts = <String, int>{};
    for (final r in rooms) {
      roomCounts[r] = all.where((d) => d.roomId == r).length;
    }

    final visible = all.where((d) => d.roomId == room).toList();
    final lights = visible.where((d) => d.type == DeviceType.light).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 400;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            screenWidth > 600 ? 32 : 22,
            16,
            screenWidth > 600 ? 32 : 22,
            24,
          ),
          children: [
            // Top App Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'LUMIVO',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.wifi_rounded,
                  color: AppColors.green,
                  size: 20,
                ),
                const SizedBox(width: 14),
                IconButton(
                  tooltip: 'Add Device',
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  onPressed: _openAddDeviceSheet,
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.muted,
                  size: 22,
                ),
                const SizedBox(width: 14),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceElevated,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Greeting & Date
            Text(
              _dateLabel(),
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: .9),
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Welcome home ✦',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your smart home is looking good.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 26),

            // Metrics Section (Responsive row / wrap)
            _buildResponsiveMetrics(screenWidth, isCompact),

            const SizedBox(height: 30),

            // Room Filter Section
            const Text(
              'Rooms',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            RoomSelector(
              rooms: rooms,
              selectedRoom: room,
              onRoomSelected: (selected) => setState(() => room = selected),
              roomDeviceCounts: roomCounts,
            ),

            const SizedBox(height: 28),

            // Devices Section Header
            Row(
              children: [
                const Text(
                  'Devices',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${visible.length} devices',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Responsive Device Cards
            _buildResponsiveDeviceGrid(visible, screenWidth),

            // Brightness Control Section
            if (lights.isNotEmpty) ...[
              const SizedBox(height: 20),
              for (final light in lights) ...[
                BrightnessSliderCard(
                  device: light,
                  brightness:
                      brightnessDraft[light.id] ?? light.brightness.toDouble(),
                  isBusy: pending.contains(light.id),
                  onChanged: (value) =>
                      setState(() => brightnessDraft[light.id] = value),
                  onChangeEnd: (value) async {
                    await _send(
                      light,
                      DeviceCommandType.setBrightness,
                      value.round(),
                    );
                    if (mounted) {
                      setState(() => brightnessDraft.remove(light.id));
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],

            const SizedBox(height: 18),

            // Status footnote
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.green,
                  size: 14,
                ),
                SizedBox(width: 7),
                Text(
                  'Demo mode · Local mock devices',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildResponsiveMetrics(double screenWidth, bool isCompact) {
    final tempCard = MetricCard(
      icon: Icons.thermostat_outlined,
      tint: AppColors.warning,
      value: '26.5°C',
      label: 'Temperature',
      statusBadge: 'Optimal',
    );

    final humidityCard = MetricCard(
      icon: Icons.water_drop_outlined,
      tint: AppColors.blue,
      value: '65%',
      label: 'Humidity',
      statusBadge: 'Comfort',
    );

    final energyCard = MetricCard(
      icon: Icons.bolt_rounded,
      tint: AppColors.green,
      value: '2.4 kWh',
      label: 'Energy Today',
      statusBadge: 'Eco',
    );

    if (screenWidth >= 640) {
      // Tablet / Desktop: 3 metrics in a row
      return Row(
        children: [
          Expanded(child: tempCard),
          const SizedBox(width: 14),
          Expanded(child: humidityCard),
          const SizedBox(width: 14),
          Expanded(child: energyCard),
        ],
      );
    } else {
      // Mobile: 2 primary metrics in a row, energy below or responsive
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: tempCard),
              const SizedBox(width: 12),
              Expanded(child: humidityCard),
            ],
          ),
          const SizedBox(height: 12),
          energyCard,
        ],
      );
    }
  }

  Widget _buildResponsiveDeviceGrid(
    List<SmartDevice> devices,
    double availableWidth,
  ) {
    final int crossAxisCount;
    if (availableWidth >= 880) {
      crossAxisCount = 4;
    } else if (availableWidth >= 580) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = availableWidth < 340 ? 1 : 2;
    }

    const double spacing = 12;
    final double itemWidth =
        (availableWidth - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final device in devices)
          SizedBox(
            width: itemWidth,
            child: DeviceCard(
              device: device,
              isBusy: pending.contains(device.id),
              onToggle: () => _send(
                device,
                DeviceCommandType.setPower,
                !device.isOn,
              ),
            ),
          ),
      ],
    );
  }

  Widget _navigation() => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        margin: const EdgeInsets.fromLTRB(18, 4, 18, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.surfaceBorder.withValues(alpha: 0.8),
          ),
          boxShadow: AppShadows.cardGlow,
        ),
        child: Row(
          children: [
            _tab(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
            _tab(1, Icons.bar_chart_outlined, Icons.bar_chart_rounded,
                'Activity'),
            _tab(2, Icons.hub_outlined, Icons.hub_rounded, 'Automation'),
            _tab(
                3, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
          ],
        ),
      );

  Widget _tab(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 21,
                color: isSelected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderTab() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.construction_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            ['', 'Activity', 'Automation', 'Settings'][selectedTab],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coming in a future milestone',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel() {
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER'
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}
