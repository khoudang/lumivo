import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';

import '../../../core/models/energy_sample.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';

final energyTariffProvider = StateProvider<double>((ref) => 0.160);

class EnergyScreen extends ConsumerStatefulWidget {
  const EnergyScreen({super.key});

  @override
  ConsumerState<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends ConsumerState<EnergyScreen> {
  EnergyPeriod _selectedPeriod = EnergyPeriod.day;
  bool _showRoomConsumption = false;

  void _showEditTariffDialog(double currentTariff, [AppLocalizations? l10n]) {
    final controller =
        TextEditingController(text: currentTariff.toStringAsFixed(3));

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text(
              'Edit Tariff Rate',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost per kilowatt-hour (\$/kWh):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('edit_tariff_rate_input'),
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '0.160',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_tariff_rate_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final newRate = double.tryParse(controller.text.trim());
              if (newRate != null && newRate > 0) {
                ref.read(energyTariffProvider.notifier).state = newRate;
                final home = ref.read(currentHomeProvider);
                ref
                    .read(homesProvider.notifier)
                    .updateHome(home.copyWith(tariffRate: newRate));
              }
              Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n?.save ?? 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final allDevices = devicesAsync.valueOrNull ?? [];
    final currentHome = ref.watch(currentHomeProvider);
    final tariffRate = ref.watch(energyTariffProvider) > 0
        ? ref.watch(energyTariffProvider)
        : currentHome.tariffRate;

    // Computed metrics depending on period
    final (double totalKWh, double avgWatts, double peakWatts) =
        switch (_selectedPeriod) {
      EnergyPeriod.day => (14.8, 616.0, 2450.0),
      EnergyPeriod.week => (98.4, 585.0, 2890.0),
      EnergyPeriod.month => (412.0, 572.0, 3120.0),
    };
    final double estimatedCost = totalKWh * tariffRate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(l10n.energyAnalytics),
        ),
        actions: [
          IconButton(
            key: const Key('export_energy_csv_button'),
            tooltip: l10n.exportCsv,
            icon: const Icon(Icons.download_rounded,
                size: 20, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.csvExported),
                  backgroundColor: AppColors.green,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: l10n.refreshTelemetry,
            onPressed: () {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.telemetryRefreshed),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Simulation Disclaimer Header Badge
            _buildSimulationHeaderBadge(l10n),

            const SizedBox(height: 16),

            // Tariff Note Card
            _buildTariffNoteCard(tariffRate, l10n),

            const SizedBox(height: 20),

            // Period Selector Tabs
            _buildPeriodSelector(),

            const SizedBox(height: 20),

            // Key Metrics Cards (Total kWh, Estimated Cost, Average Watts, Peak Watts)
            _buildMetricsCards(
                totalKWh, estimatedCost, avgWatts, peakWatts, tariffRate, l10n),

            const SizedBox(height: 26),

            // Notice banner stating calculations are simulated estimates
            Container(
              key: const Key('energy_simulated_notice_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.cyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.simulatedEnergyNotice,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Energy History Chart
            _buildHistoryChart(),

            const SizedBox(height: 28),

            // Breakdown View Selector (Per-Device vs Per-Room)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ChoiceChip(
                    key: const Key('energy_view_device_tab'),
                    label: Text(l10n.perDeviceConsumption),
                    selected: !_showRoomConsumption,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) =>
                        setState(() => _showRoomConsumption = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('energy_view_room_tab'),
                    label: Text(l10n.perRoomConsumption),
                    selected: _showRoomConsumption,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) =>
                        setState(() => _showRoomConsumption = true),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Device vs Room Breakdown List
            if (!_showRoomConsumption)
              _buildDeviceBreakdownList(allDevices, totalKWh, tariffRate, l10n)
            else
              _buildRoomBreakdownList(allDevices, totalKWh, tariffRate, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationHeaderBadge([AppLocalizations? l10n]) {
    return Container(
      key: const Key('energy_simulation_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cyan.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors_rounded, color: AppColors.cyan, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.simulatedTelemetryBanner ??
                  'SIMULATED TELEMETRY • VIRTUAL ESTIMATE',
              style: TextStyle(
                color: AppColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTariffNoteCard(double tariffRate, [AppLocalizations? l10n]) {
    return Container(
      key: const Key('energy_tariff_note'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD572).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.electric_bolt_rounded,
              color: Color(0xFFFFD572),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.currentTariff ?? 'Current Tariff',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${tariffRate.toStringAsFixed(3)} / kWh (Simulated)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('edit_tariff_button'),
            onPressed: () => _showEditTariffDialog(tariffRate),
            icon: const Icon(Icons.edit_outlined,
                size: 14, color: AppColors.primary),
            label: const Text(
              'Edit',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          _periodTab('Day', EnergyPeriod.day, const Key('period_tab_day')),
          _periodTab('Week', EnergyPeriod.week, const Key('period_tab_week')),
          _periodTab(
              'Month', EnergyPeriod.month, const Key('period_tab_month')),
        ],
      ),
    );
  }

  Widget _periodTab(String label, EnergyPeriod period, Key key) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedPeriod = period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? AppShadows.primaryGlow : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsCards(
    double totalKWh,
    double estimatedCost,
    double avgWatts,
    double peakWatts,
    double tariffRate,
    AppLocalizations? l10n,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                key: const Key('metric_total_kwh'),
                icon: Icons.bolt_rounded,
                tint: AppColors.green,
                label: l10n?.totalKwh ?? 'Total kWh',
                value: '${totalKWh.toStringAsFixed(1)} kWh',
                subtitle: '-5.2% vs prior',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                key: const Key('metric_estimated_cost'),
                icon: Icons.attach_money_rounded,
                tint: const Color(0xFFFFD572),
                label: l10n?.estimatedCost ?? 'Estimated Cost',
                value: '\$${estimatedCost.toStringAsFixed(2)}',
                subtitle: '@ \$${tariffRate.toStringAsFixed(3)}/kWh',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                key: const Key('metric_average_watts'),
                icon: Icons.speed_rounded,
                tint: AppColors.cyan,
                label: l10n?.averageWatts ?? 'Average Watts',
                value: '${avgWatts.toStringAsFixed(0)} W',
                subtitle: 'Baseline continuous',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                key: const Key('metric_peak_watts'),
                icon: Icons.trending_up_rounded,
                tint: AppColors.danger,
                label: l10n?.peakWatts ?? 'Peak Watts',
                value: '${peakWatts.toStringAsFixed(0)} W',
                subtitle: 'Spike load telemetry',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard({
    required Key key,
    required IconData icon,
    required Color tint,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tint, size: 18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChart() {
    final (List<String> labels, List<double> values) =
        switch (_selectedPeriod) {
      EnergyPeriod.day => (
          [
            '00h',
            '02h',
            '04h',
            '06h',
            '08h',
            '10h',
            '12h',
            '14h',
            '16h',
            '18h',
            '20h',
            '22h'
          ],
          [0.4, 0.3, 0.2, 0.6, 1.4, 1.8, 2.1, 1.9, 1.6, 2.4, 1.7, 0.5],
        ),
      EnergyPeriod.week => (
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          [13.8, 14.2, 12.9, 15.6, 16.2, 18.4, 17.3],
        ),
      EnergyPeriod.month => (
          ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
          [96.0, 104.5, 98.2, 113.3],
        ),
    };

    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Container(
      key: const Key('energy_history_chart'),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Energy History',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Max: ${maxVal.toStringAsFixed(1)} kWh',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (idx) {
                final val = values[idx];
                final ratio =
                    maxVal > 0 ? (val / maxVal).clamp(0.08, 1.0) : 0.1;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          val.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: ratio,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.cyan],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryGlow
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[idx],
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceBreakdownList(
    List<SmartDevice> devices,
    double totalKWh,
    double tariffRate,
    AppLocalizations? l10n,
  ) {
    // Curated simulation device usage list if devices is empty or to supplement
    final effectiveDevices = devices.isNotEmpty
        ? devices
        : const [
            SmartDevice(
              id: 'ac-demo',
              name: 'Living Room AC',
              roomId: 'Living Room',
              type: DeviceType.ac,
              isOn: true,
            ),
            SmartDevice(
              id: 'light-demo',
              name: 'Kitchen Main Light',
              roomId: 'Kitchen',
              type: DeviceType.light,
              isOn: true,
            ),
            SmartDevice(
              id: 'fan-demo',
              name: 'Master Bedroom Fan',
              roomId: 'Bedroom',
              type: DeviceType.fan,
              isOn: true,
            ),
          ];

    // Compute device shares
    final shares = <String, double>{
      for (int i = 0; i < effectiveDevices.length; i++)
        effectiveDevices[i].id: (effectiveDevices.length - i).toDouble() /
            (effectiveDevices.length * (effectiveDevices.length + 1) / 2),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Device Energy Breakdown',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${effectiveDevices.length} tracked',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: effectiveDevices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final dev = effectiveDevices[idx];
            final shareRatio = shares[dev.id] ?? 0.2;
            final devKWh = totalKWh * shareRatio;
            final devCost = devKWh * tariffRate;
            final percentage = (shareRatio * 100).toStringAsFixed(1);

            return Container(
              key: Key('device_energy_item_${dev.id}'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getDeviceIcon(dev.type),
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              dev.roomId,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${devKWh.toStringAsFixed(2)} kWh',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '\$${devCost.toStringAsFixed(2)} • $percentage%',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: shareRatio.clamp(0.05, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return Icons.lightbulb_rounded;
      case DeviceType.fan:
        return Icons.mode_fan_off_outlined;
      case DeviceType.security:
        return Icons.shield_rounded;
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

  Widget _buildRoomBreakdownList(
    List<SmartDevice> devices,
    double totalKWh,
    double tariffRate,
    AppLocalizations? l10n,
  ) {
    const rooms = ['Living Room', 'Bedroom', 'Kitchen'];
    const roomShares = {'Living Room': 0.50, 'Bedroom': 0.30, 'Kitchen': 0.20};

    return Column(
      key: const Key('per_room_consumption_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n?.perRoomConsumption ?? 'Per-Room Consumption',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${rooms.length} rooms',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final roomName = rooms[idx];
            final share = roomShares[roomName] ?? 0.33;
            final roomKWh = totalKWh * share;
            final roomCost = roomKWh * tariffRate;
            final percentage = (share * 100).toStringAsFixed(1);

            return Container(
              key: Key(
                  'room_energy_item_${roomName.toLowerCase().replaceAll(" ", "_")}'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.meeting_room_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          roomName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${roomKWh.toStringAsFixed(2)} kWh',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '\$${roomCost.toStringAsFixed(2)} • $percentage%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: share.clamp(0.05, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
