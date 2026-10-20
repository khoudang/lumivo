import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

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
      SmartDevice device, DeviceCommandType type, Object value) async {
    if (pending.contains(device.id)) return;
    setState(() => pending.add(device.id));
    final result = await ref.read(deviceRepositoryProvider).sendCommand(
          DeviceCommand(
              requestId: 'local-${++serial}',
              deviceId: device.id,
              type: type,
              value: value),
        );
    if (!mounted) return;
    setState(() => pending.remove(device.id));
    if (result.status != CommandStatus.confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? 'Command failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
              child: selectedTab == 0
                  ? devices.when(
                      data: (all) => _home(all),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Error: $error')),
                    )
                  : Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.construction_rounded,
                          size: 50, color: AppColors.primary),
                      const SizedBox(height: 14),
                      Text(
                          [
                            '',
                            'Activity',
                            'Automation',
                            'Settings'
                          ][selectedTab],
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 5),
                      const Text('Coming in a future milestone',
                          style: TextStyle(color: AppColors.muted)),
                    ]))),
          _navigation(),
        ]),
      ),
    );
  }

  Widget _home(List<SmartDevice> all) {
    final visible = all.where((d) => d.roomId == room).toList();
    final lights = visible.where((d) => d.type == DeviceType.light).toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
        children: [
          Row(children: [
            const Icon(Icons.home_rounded, color: AppColors.primary, size: 27),
            const SizedBox(width: 8),
            const Text('LUMIVO',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: 1.5)),
            const Spacer(),
            const Icon(Icons.wifi_rounded, color: AppColors.green),
            const SizedBox(width: 18),
            const Icon(Icons.notifications_none_rounded,
                color: AppColors.muted),
            const SizedBox(width: 16),
            const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceElevated,
                child: Icon(Icons.person_outline_rounded,
                    color: Colors.white, size: 20)),
          ]),
          const SizedBox(height: 32),
          Text(_dateLabel(),
              style: TextStyle(
                  color: AppColors.muted.withValues(alpha: .9),
                  fontSize: 11,
                  letterSpacing: 1.6)),
          const SizedBox(height: 9),
          const Text('Welcome home ✦',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Your smart home is looking good.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 27),
          Row(children: [
            Expanded(
                child: _metric(Icons.thermostat_outlined,
                    const Color(0xFFFFBE7C), '26.5°C', 'Temperature')),
            const SizedBox(width: 12),
            Expanded(
                child: _metric(Icons.water_drop_outlined,
                    const Color(0xFF77CFFF), '65%', 'Humidity')),
          ]),
          const SizedBox(height: 30),
          const Text('Rooms',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 13),
          SizedBox(
              height: 42,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final name in ['Living Room', 'Bedroom', 'Kitchen']) ...[
                  ChoiceChip(
                    label: Text(name),
                    selected: room == name,
                    onSelected: (_) => setState(() => room = name),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary.withValues(alpha: .32),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                        color: room == name ? Colors.white : AppColors.muted),
                  ),
                  const SizedBox(width: 9),
                ],
              ])),
          const SizedBox(height: 25),
          Row(children: [
            const Text('Devices',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${visible.length} devices',
                style: const TextStyle(color: AppColors.primary, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final device in visible)
                SizedBox(width: width, child: _deviceCard(device)),
            ]);
          }),
          if (lights.isNotEmpty) ...[
            const SizedBox(height: 17),
            _brightnessCard(lights.first),
          ],
          const SizedBox(height: 15),
          const Row(children: [
            Icon(Icons.check_circle_outline, color: AppColors.green, size: 14),
            SizedBox(width: 7),
            Text('Demo mode · Local mock devices',
                style: TextStyle(color: AppColors.muted, fontSize: 11))
          ]),
        ]);
  }

  Widget _metric(IconData icon, Color tint, String value, String label) =>
      Container(
          padding: const EdgeInsets.all(19),
          decoration: _decoration(AppColors.surface),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: tint, size: 26),
            const SizedBox(height: 17),
            Text(value,
                style:
                    const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]));

  Widget _deviceCard(SmartDevice device) {
    final busy = pending.contains(device.id);
    final icon = switch (device.type) {
      DeviceType.light => Icons.lightbulb_outline_rounded,
      DeviceType.fan => Icons.mode_fan_off_outlined,
      DeviceType.security => Icons.shield_outlined,
    };
    final activeColor = device.type == DeviceType.security
        ? const Color(0xFF174139)
        : const Color(0xFF493F85);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: busy
          ? null
          : () => _send(device, DeviceCommandType.setPower, !device.isOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: _decoration(device.isOn ? activeColor : AppColors.surface),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon,
                color: device.isOn ? const Color(0xFFE8DEFF) : AppColors.muted,
                size: 26),
            const Spacer(),
            if (busy)
              const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(device.isOn ? Icons.toggle_on : Icons.toggle_off,
                  color: device.isOn ? AppColors.green : AppColors.muted,
                  size: 28),
          ]),
          const SizedBox(height: 25),
          Text(device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text('${device.isOn ? 'On' : 'Off'} · ${device.roomId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    );
  }

  Widget _brightnessCard(SmartDevice light) {
    final level = brightnessDraft[light.id] ?? light.brightness.toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 9),
      decoration: _decoration(AppColors.surface),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.wb_sunny_outlined,
              color: Color(0xFFE7C184), size: 23),
          const SizedBox(width: 10),
          const Text('Brightness',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${level.round()}%',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ]),
        Slider(
          value: level,
          min: 0,
          max: 100,
          onChanged: pending.contains(light.id)
              ? null
              : (value) => setState(() => brightnessDraft[light.id] = value),
          onChangeEnd: pending.contains(light.id)
              ? null
              : (value) async {
                  await _send(
                      light, DeviceCommandType.setBrightness, value.round());
                  if (mounted) setState(() => brightnessDraft.remove(light.id));
                },
        ),
      ]),
    );
  }

  Widget _navigation() => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        margin: const EdgeInsets.fromLTRB(18, 3, 18, 8),
        decoration: _decoration(AppColors.surface),
        child: Row(children: [
          _tab(0, Icons.home_outlined, 'Home'),
          _tab(1, Icons.bar_chart_outlined, 'Activity'),
          _tab(2, Icons.hub_outlined, 'Automation'),
          _tab(3, Icons.settings_outlined, 'Settings'),
        ]),
      );

  Widget _tab(int index, IconData icon, String label) => Expanded(
          child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: selectedTab == index
                  ? const Color(0xFF2C2B48)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15)),
          child: Column(children: [
            Icon(icon,
                size: 21,
                color:
                    selectedTab == index ? AppColors.primary : AppColors.muted),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color:
                        selectedTab == index ? Colors.white : AppColors.muted))
          ]),
        ),
      ));

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

  BoxDecoration _decoration(Color color) =>
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(22));
}
