import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/discovered_device.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/state/user_profile_notifier.dart';

enum _AddDeviceStep {
  scanning,
  wifiInput,
  provisioning,
  success,
  timeout,
}

/// A dark minimal modal bottom sheet for discovering, provisioning,
/// and adding a new Lumivo smart device.
class AddDeviceSheet extends ConsumerStatefulWidget {
  const AddDeviceSheet({
    super.key,
    this.onDeviceAdded,
    this.simulateTimeout = false,
  });

  final void Function(SmartDevice newDevice)? onDeviceAdded;
  final bool simulateTimeout;

  /// Helper to display the Add Device bottom sheet modally.
  static Future<T?> show<T>(
    BuildContext context, {
    void Function(SmartDevice newDevice)? onDeviceAdded,
    bool simulateTimeout = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AddDeviceSheet(
        onDeviceAdded: onDeviceAdded,
        simulateTimeout: simulateTimeout,
      ),
    );
  }

  @override
  ConsumerState<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<AddDeviceSheet>
    with SingleTickerProviderStateMixin {
  _AddDeviceStep _currentStep = _AddDeviceStep.scanning;
  late final AnimationController _pulseController;

  // Selected device & Wi-Fi state
  DiscoveredDevice? _selectedDevice;
  final _ssidController = TextEditingController(text: 'Lumivo_Home_5G');
  final _passwordController = TextEditingController(text: 'lumivo#secure2026');
  bool _obscurePassword = true;

  // Provisioning progress state
  int _provisioningPhase = 0; // 0..3
  Timer? _provisioningTimer;

  // Final room assignment
  String _assignedRoom = 'Living Room';

  // Discovered mock devices
  final List<DiscoveredDevice> _mockDiscovered = [
    const DiscoveredDevice(
      id: 'lumivo-light-neo',
      name: 'Lumivo Ambient Aura',
      rssi: -52,
      type: DeviceType.light,
    ),
    const DiscoveredDevice(
      id: 'lumivo-fan-breeze',
      name: 'Lumivo Aero Breeze',
      rssi: -67,
      type: DeviceType.fan,
    ),
    const DiscoveredDevice(
      id: 'lumivo-guard-shield',
      name: 'Lumivo Guard Sentinel',
      rssi: -81,
      type: DeviceType.security,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    bool isReduced = false;
    try {
      isReduced = ref.read(userProfileProvider).reducedMotion;
    } catch (_) {}
    if (!isReduced) {
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _provisioningTimer?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectDevice(DiscoveredDevice device) {
    setState(() {
      _selectedDevice = device;
      _currentStep = _AddDeviceStep.wifiInput;
    });
  }

  void _startProvisioning() {
    setState(() {
      _currentStep = _AddDeviceStep.provisioning;
      _provisioningPhase = 0;
    });

    _provisioningTimer?.cancel();

    if (widget.simulateTimeout) {
      _provisioningTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _currentStep = _AddDeviceStep.timeout);
      });
      return;
    }

    _provisioningTimer =
        Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_provisioningPhase < 3) {
        setState(() => _provisioningPhase++);
      } else {
        timer.cancel();
        setState(() => _currentStep = _AddDeviceStep.success);
      }
    });
  }

  void _retryPairing() {
    setState(() {
      _currentStep = _AddDeviceStep.provisioning;
      _provisioningPhase = 0;
    });

    _provisioningTimer?.cancel();
    _provisioningTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_provisioningPhase < 3) {
        setState(() => _provisioningPhase++);
      } else {
        timer.cancel();
        setState(() => _currentStep = _AddDeviceStep.success);
      }
    });
  }

  void _cancelFlow() {
    _provisioningTimer?.cancel();
    if (_currentStep == _AddDeviceStep.scanning ||
        _currentStep == _AddDeviceStep.timeout) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _currentStep = _AddDeviceStep.scanning;
        _provisioningPhase = 0;
      });
    }
  }

  void _finishAndClose() {
    if (_selectedDevice != null) {
      final newDevice = SmartDevice(
        id: _selectedDevice!.id,
        name: _selectedDevice!.name,
        roomId: _assignedRoom,
        type: _selectedDevice!.type,
        isOn: true,
        brightness: _selectedDevice!.type == DeviceType.light ? 80 : 100,
        connection: DeviceConnection.online,
      );
      widget.onDeviceAdded?.call(newDevice);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    bool isReduced = false;
    try {
      isReduced = ref.watch(userProfileProvider).reducedMotion;
    } catch (_) {
      isReduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    }
    final l10n = AppLocalizations.of(context);
    if (isReduced && _pulseController.isAnimating) {
      _pulseController.stop();
    } else if (!isReduced && !_pulseController.isAnimating) {
      _pulseController.repeat();
    }
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 640),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title bar with back / close button
              Row(
                children: [
                  if (_currentStep == _AddDeviceStep.wifiInput)
                    Semantics(
                      button: true,
                      label: l10n?.back ?? 'Back',
                      child: IconButton(
                        tooltip: l10n?.back ?? 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                        padding: const EdgeInsets.all(12),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => setState(
                            () => _currentStep = _AddDeviceStep.scanning),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _stepTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n?.cancel ?? 'Cancel',
                    child: IconButton(
                      key: _currentStep == _AddDeviceStep.timeout
                          ? null
                          : const Key('onboarding_cancel_button'),
                      tooltip: l10n?.cancel ?? 'Cancel',
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.muted),
                      padding: const EdgeInsets.all(12),
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: _cancelFlow,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Body content based on step
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: switch (_currentStep) {
                      _AddDeviceStep.scanning => _buildScanningView(),
                      _AddDeviceStep.wifiInput => _buildWifiInputView(),
                      _AddDeviceStep.provisioning => _buildProvisioningView(),
                      _AddDeviceStep.success => _buildSuccessView(),
                      _AddDeviceStep.timeout => _buildTimeoutView(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stepTitle() {
    final l10n = AppLocalizations.of(context);
    switch (_currentStep) {
      case _AddDeviceStep.scanning:
        return l10n?.discoveredDevices ?? 'Discovered Devices';
      case _AddDeviceStep.wifiInput:
        return l10n?.wifiSetup ?? 'Wi-Fi Setup';
      case _AddDeviceStep.provisioning:
        return l10n?.pairingDevice ?? 'Pairing Device';
      case _AddDeviceStep.success:
        return l10n?.deviceReady ?? 'Device Ready';
      case _AddDeviceStep.timeout:
        return l10n?.pairingTimeout ?? 'Pairing timed out';
    }
  }

  // -------------------------------------------------------------
  // Step 1: Scanning View
  // -------------------------------------------------------------
  Widget _buildScanningView() {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('scanning'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Radar Pulse Animation with Concentric Pulsating Rings
        SizedBox(
          height: 140,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RadarPulsePainter(progress: _pulseController.value),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      boxShadow: AppShadows.primaryGlow,
                    ),
                    child: const Icon(
                      Icons.bluetooth_searching_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        Text(
          l10n?.scanningForDevices ?? 'Scanning for nearby BLE devices...',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 8),

        // Live Discovered Devices Count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '${_mockDiscovered.length} ${l10n?.devicesFound ?? "devices found"}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),

        const SizedBox(height: 18),

        // List of mock discovered devices
        ..._mockDiscovered.map((device) => _discoveredDeviceTile(device)),
      ],
    );
  }

  Widget _discoveredDeviceTile(DiscoveredDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: () => _selectDevice(device),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getDeviceIcon(device.type),
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            device.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _signalBars(device.rssi),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${device.rssi} dBm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)?.connect ?? 'Connect',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signalBars(int rssi) {
    final bars = rssi >= -60
        ? 4
        : rssi >= -70
            ? 3
            : rssi >= -85
                ? 2
                : 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < bars;
        return Container(
          width: 3,
          height: 5.0 + (i * 3.0),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active ? AppColors.green : AppColors.mutedDark,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // -------------------------------------------------------------
  // Step 2: Wi-Fi Provisioning Form
  // -------------------------------------------------------------
  Widget _buildWifiInputView() {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('wifiInput'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedDevice != null)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                Icon(
                  _getDeviceIcon(_selectedDevice!.type),
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDevice!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        l10n?.readyToPair ??
                            'Ready to pair with home Wi-Fi network',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          l10n?.wifiNetworkSsid ?? 'Wi-Fi Network (SSID)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ssidController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.wifi_rounded),
            hintText: l10n?.enterWifiSsid ?? 'Enter Wi-Fi SSID',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n?.wifiPassword ?? 'Wi-Fi Password',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            hintText: l10n?.enterWifiPassword ?? 'Enter Password',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _startProvisioning,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, size: 20),
                const SizedBox(width: 8),
                Text(l10n?.provisionAndConnect ?? 'Provision & Connect Device'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 3: Provisioning Progress
  // -------------------------------------------------------------
  Widget _buildProvisioningView() {
    final l10n = AppLocalizations.of(context);
    final steps = [
      l10n?.connectingBle ?? 'Connecting to device via BLE...',
      l10n?.configuringWifi ?? 'Configuring Wi-Fi credentials...',
      l10n?.verifyingMqtt ?? 'Verifying cloud MQTT link...',
      l10n?.finalizingConfig ?? 'Finalizing configuration...',
    ];

    final progressPercent = ((_provisioningPhase + 1) / 4).clamp(0.0, 1.0);

    return Column(
      key: const ValueKey('provisioning'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),

        // Animated progress track
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressPercent,
            minHeight: 8,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),

        const SizedBox(height: 28),

        // Step checklist
        for (int i = 0; i < steps.length; i++) ...[
          _provisioningStepRow(
            stepIndex: i,
            title: steps[i],
            isActive: i == _provisioningPhase,
            isCompleted: i < _provisioningPhase,
          ),
          if (i < steps.length - 1)
            Container(
              margin: const EdgeInsets.only(left: 17, top: 2, bottom: 2),
              width: 2,
              height: 20,
              color: i < _provisioningPhase
                  ? AppColors.green
                  : AppColors.surfaceBorder,
            ),
        ],

        const SizedBox(height: 24),

        // Cancel Pairing Button with minimum 48pt touch height
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('provisioning_cancel_button'),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text(l10n?.cancelPairing ?? 'Cancel Pairing'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: AppColors.surfaceBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _cancelFlow,
          ),
        ),
      ],
    );
  }

  Widget _provisioningStepRow({
    required int stepIndex,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.green.withValues(alpha: 0.18)
                : isActive
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted
                  ? AppColors.green
                  : isActive
                      ? AppColors.primary
                      : AppColors.surfaceBorder,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded,
                    color: AppColors.green, size: 20)
                : isActive
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        '${stepIndex + 1}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  isActive || isCompleted ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? AppColors.textPrimary
                  : isCompleted
                      ? AppColors.textSecondary
                      : AppColors.mutedDark,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 4: Success View
  // -------------------------------------------------------------
  Widget _buildSuccessView() {
    final l10n = AppLocalizations.of(context);
    const availableRooms = [
      'Living Room',
      'Bedroom',
      'Kitchen',
      'Office',
      'Balcony',
    ];

    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),

        // Glowing Success Badge
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.green,
                width: 2,
              ),
              boxShadow: AppShadows.greenGlow,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.green,
              size: 38,
            ),
          ),
        ),

        const SizedBox(height: 18),

        const Center(
          child: Text(
            'Device Ready!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: 6),

        Center(
          child: Text(
            '${_selectedDevice?.name ?? 'Lumivo Device'} has been successfully paired.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          l10n?.assignRoom ?? 'Assign Room',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Room Assignment Dropdown
        DropdownButtonFormField<String>(
          key: const Key('room_assignment_dropdown'),
          initialValue: _assignedRoom,
          isExpanded: true,
          dropdownColor: AppColors.surfaceElevated,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            prefixIcon: const Icon(
              Icons.meeting_room_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
          items: availableRooms
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      r,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _assignedRoom = val);
          },
        ),

        const SizedBox(height: 12),

        // Quick Choice Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableRooms
              .map((room) => ChoiceChip(
                    label: Text(room),
                    selected: _assignedRoom == room,
                    onSelected: (_) => setState(() => _assignedRoom = room),
                    selectedColor: AppColors.primary.withValues(alpha: 0.28),
                    backgroundColor: AppColors.surfaceElevated,
                    labelStyle: TextStyle(
                      color: _assignedRoom == room
                          ? Colors.white
                          : AppColors.muted,
                      fontWeight: _assignedRoom == room
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ))
              .toList(),
        ),

        const SizedBox(height: 28),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _finishAndClose,
            child: Text(
                l10n?.completeAndDashboard ?? 'Complete & Go to Dashboard'),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 5: Timeout View with Retry and Cancel Flows
  // -------------------------------------------------------------
  Widget _buildTimeoutView() {
    final l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey('timeout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.warning,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            l10n?.pairingTimeout ?? 'Pairing timed out',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            l10n?.pairingTimeoutDesc ??
                'Unable to establish BLE handshake or transfer credentials within the timeout window. Please verify Bluetooth proximity.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('onboarding_retry_button'),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              l10n?.retryPairing ?? 'Retry Pairing',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _retryPairing,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('onboarding_cancel_button'),
            icon: const Icon(Icons.close_rounded, size: 20),
            label: Text(
              l10n?.cancel ?? 'Cancel',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: AppColors.surfaceBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _cancelFlow,
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
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

class _RadarPulsePainter extends CustomPainter {
  const _RadarPulsePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 30.0 + (ringProgress * 45.0);
      final alpha = ((1.0 - ringProgress) * 0.35).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
