import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/activity_event.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import 'device_settings_sheet.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  const DeviceDetailScreen({
    super.key,
    required this.device,
    this.enableAnimationsInTest = false,
  });

  final SmartDevice device;
  final bool enableAnimationsInTest;

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen>
    with TickerProviderStateMixin {
  late SmartDevice _localDevice;
  bool _isSending = false;

  // Fan rotation animation
  late AnimationController _fanController;

  // Lock pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Local draft states
  String _selectedFanSpeed = 'Medium';
  String _selectedAcMode = 'Cool';
  String _selectedColorPreset = 'Warm 2700K';

  @override
  void initState() {
    super.initState();
    _localDevice = widget.device;

    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final inTest = WidgetsBinding.instance is! WidgetsFlutterBinding;
    final isReduced = ref.read(userProfileProvider).reducedMotion;
    final canAnimate = (!inTest || widget.enableAnimationsInTest) && !isReduced;
    if (_localDevice.isOn && canAnimate) {
      _fanController.repeat();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (canAnimate) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant DeviceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _localDevice = widget.device;
    }
  }

  @override
  void dispose() {
    _fanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateFanSpeed(String speed) {
    final inTest = WidgetsBinding.instance is! WidgetsFlutterBinding;
    final isReduced = ref.read(userProfileProvider).reducedMotion;
    final canAnimate = (!inTest || widget.enableAnimationsInTest) && !isReduced;
    setState(() => _selectedFanSpeed = speed);
    switch (speed) {
      case 'Off':
        _sendCommand(DeviceCommandType.setPower, false);
        _fanController.stop();
        break;
      case 'Low':
        if (!_localDevice.isOn) _sendCommand(DeviceCommandType.setPower, true);
        _fanController.duration = const Duration(milliseconds: 1500);
        if (canAnimate) _fanController.repeat();
        break;
      case 'Medium':
        if (!_localDevice.isOn) _sendCommand(DeviceCommandType.setPower, true);
        _fanController.duration = const Duration(milliseconds: 900);
        if (canAnimate) _fanController.repeat();
        break;
      case 'High':
        if (!_localDevice.isOn) _sendCommand(DeviceCommandType.setPower, true);
        _fanController.duration = const Duration(milliseconds: 450);
        if (canAnimate) _fanController.repeat();
        break;
    }
  }

  Future<void> _sendCommand(DeviceCommandType type, Object value) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final inTest = WidgetsBinding.instance is! WidgetsFlutterBinding;
    final isReduced = ref.read(userProfileProvider).reducedMotion;
    final canAnimate = (!inTest || widget.enableAnimationsInTest) && !isReduced;

    // Optimistically update local device
    switch (type) {
      case DeviceCommandType.setPower:
        final nextPower = value as bool;
        _localDevice = _localDevice.copyWith(isOn: nextPower);
        if (nextPower) {
          if (canAnimate) _fanController.repeat();
        } else {
          _fanController.stop();
        }
        break;
      case DeviceCommandType.setBrightness:
        final b = (value as int).clamp(0, 100);
        _localDevice = _localDevice.copyWith(brightness: b, isOn: b > 0);
        break;
      case DeviceCommandType.setTargetTemperature:
        final t = (value as num).toDouble().clamp(16.0, 30.0);
        _localDevice = _localDevice.copyWith(targetTemperature: t);
        break;
      case DeviceCommandType.setPosition:
        final p = (value as int).clamp(0, 100);
        _localDevice = _localDevice.copyWith(position: p);
        break;
      case DeviceCommandType.setLock:
        _localDevice = _localDevice.copyWith(isLocked: value as bool);
        break;
      case DeviceCommandType.toggleLock:
        _localDevice = _localDevice.copyWith(isLocked: !_localDevice.isLocked);
        break;
    }
    setState(() {});

    final result = await ref.read(deviceRepositoryProvider).sendCommand(
          DeviceCommand(
            requestId: 'cmd-${DateTime.now().millisecondsSinceEpoch}',
            deviceId: _localDevice.id,
            type: type,
            value: value,
          ),
        );

    // Record activity event
    ref.read(activityProvider.notifier).addEvent(
          ActivityEvent(
            id: 'act-${DateTime.now().millisecondsSinceEpoch}',
            title: '${_localDevice.name}: ${type.name}',
            description: 'Set value to $value (Status: ${result.status.name})',
            timestamp: DateTime.now(),
            deviceId: _localDevice.id,
            roomId: _localDevice.roomId,
            severity: result.status == CommandStatus.confirmed
                ? ActivitySeverity.success
                : ActivitySeverity.warning,
            source: 'manual',
          ),
        );

    if (mounted) {
      setState(() => _isSending = false);
      if (result.status != CommandStatus.confirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Command failed'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = ref.watch(userProfileProvider).reducedMotion;
    if (reducedMotion) {
      if (_fanController.isAnimating) _fanController.stop();
      if (_pulseController.isAnimating) _pulseController.stop();
    }
    // Reactively watch device updates from repository
    final devicesAsync = ref.watch(devicesProvider);
    final currentDevice = devicesAsync.valueOrNull?.firstWhere(
          (d) => d.id == _localDevice.id,
          orElse: () => _localDevice,
        ) ??
        _localDevice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(currentDevice.name),
        actions: [
          // Favorite Star Toggle
          IconButton(
            key: const Key('device_detail_favorite_button'),
            tooltip:
                currentDevice.isFavorite ? 'Unpin Favorite' : 'Pin Favorite',
            icon: Icon(
              currentDevice.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: currentDevice.isFavorite
                  ? const Color(0xFFFFD572)
                  : AppColors.muted,
              size: 24,
            ),
            onPressed: () {
              final updated = currentDevice.copyWith(
                isFavorite: !currentDevice.isFavorite,
              );
              final repo = ref.read(deviceRepositoryProvider);
              if (repo is MockDeviceRepository) {
                repo.updateDevice(updated);
              }
              setState(() => _localDevice = updated);
            },
          ),
          IconButton(
            icon: Icon(
              currentDevice.connection == DeviceConnection.online
                  ? Icons.wifi_rounded
                  : Icons.wifi_off_rounded,
              color: currentDevice.connection == DeviceConnection.online
                  ? AppColors.green
                  : AppColors.danger,
              size: 20,
            ),
            tooltip: currentDevice.connection == DeviceConnection.online
                ? 'Online'
                : 'Offline',
            onPressed: () {},
          ),
          // Settings Gear Icon
          IconButton(
            key: const Key('device_detail_settings_button'),
            tooltip: 'Device Settings',
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: () {
              DeviceSettingsSheet.show(
                context,
                currentDevice,
                onSave: (updated) {
                  setState(() => _localDevice = updated);
                },
                onDelete: (_) {
                  Navigator.of(context).pop();
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                return ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 14 : 24,
                    vertical: 16,
                  ),
                  children: [
                    _buildDeviceStatusHeader(currentDevice),
                    const SizedBox(height: 24),
                    _buildSpecializedControl(currentDevice),
                    const SizedBox(height: 24),
                    _buildDeviceInfoCard(currentDevice),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceStatusHeader(SmartDevice device) {
    final isOnline = device.connection == DeviceConnection.online;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: device.isOn
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: device.isOn
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              _deviceIcon(device),
              color: device.isOn ? AppColors.primary : AppColors.muted,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? AppColors.green.withValues(alpha: 0.15)
                            : AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  isOnline ? AppColors.green : AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  isOnline ? AppColors.green : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(
                        device.roomId,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSending)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecializedControl(SmartDevice device) {
    switch (device.type) {
      case DeviceType.light:
        return _buildLightControls(device);
      case DeviceType.fan:
        return _buildFanControls(device);
      case DeviceType.ac:
        return _buildClimateControls(device);
      case DeviceType.socket:
        return _buildSocketControls(device);
      case DeviceType.curtain:
        return _buildCurtainControls(device);
      case DeviceType.lock:
        return _buildLockControls(device);
      case DeviceType.sensor:
        return _buildSensorControls(device);
      case DeviceType.security:
        return _buildSecurityControls(device);
    }
  }

  // 1. Light / Bulb Controls
  Widget _buildLightControls(SmartDevice device) {
    const moods = [
      'Warm 2700K',
      'Neutral 4000K',
      'Cool 6500K',
      'Night 1800K',
      'Reading',
      'Relax',
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Light Controls',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: device.isOn,
                activeThumbColor: AppColors.primary,
                onChanged: (val) =>
                    _sendCommand(DeviceCommandType.setPower, val),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Brightness',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${device.brightness}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Semantics(
            slider: true,
            label: '${device.name} brightness',
            value: '${device.brightness}%',
            child: SizedBox(
              height: 48,
              child: Slider(
                value: device.brightness.toDouble(),
                min: 0,
                max: 100,
                onChanged: (val) {
                  setState(() {
                    _localDevice = _localDevice.copyWith(
                        brightness: val.round(), isOn: val > 0);
                  });
                },
                onChangeEnd: (val) =>
                    _sendCommand(DeviceCommandType.setBrightness, val.round()),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Color Temperature & Moods',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: moods.map((mood) {
              final isSelected = _selectedColorPreset == mood;
              return ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text(mood),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.25),
                backgroundColor: AppColors.surfaceElevated,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color:
                      isSelected ? AppColors.primary : AppColors.surfaceBorder,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedColorPreset = mood);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 2. Fan Controls
  Widget _buildFanControls(SmartDevice device) {
    const speeds = ['Off', 'Low', 'Medium', 'High'];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Fan Speed Control',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: device.isOn,
                activeThumbColor: AppColors.cyan,
                onChanged: (val) =>
                    _sendCommand(DeviceCommandType.setPower, val),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: RotationTransition(
              turns: _fanController,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: device.isOn
                      ? AppColors.cyan.withValues(alpha: 0.12)
                      : AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: device.isOn
                        ? AppColors.cyan.withValues(alpha: 0.3)
                        : AppColors.surfaceBorder,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.mode_fan_off_outlined,
                  size: 54,
                  color: device.isOn ? AppColors.cyan : AppColors.muted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: speeds.map((speed) {
              final isSelected = (!device.isOn && speed == 'Off') ||
                  (device.isOn && _selectedFanSpeed == speed);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () => _updateFanSpeed(speed),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: isSelected
                          ? AppColors.cyan
                          : AppColors.surfaceElevated,
                      foregroundColor:
                          isSelected ? Colors.black : AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.cyan
                              : AppColors.surfaceBorder,
                        ),
                      ),
                    ),
                    child: Text(
                      speed,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 3. AC / Climate Controls
  Widget _buildClimateControls(SmartDevice device) {
    const modes = ['Cool', 'Heat', 'Fan', 'Eco', 'Off'];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Climate Control',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'Current: ${device.currentTemperature.toStringAsFixed(1)}°C',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.remove_rounded, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: () {
                  final next =
                      (device.targetTemperature - 0.5).clamp(16.0, 30.0);
                  _sendCommand(DeviceCommandType.setTargetTemperature, next);
                },
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${device.targetTemperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'TARGET TEMPERATURE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                icon: const Icon(Icons.add_rounded, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: () {
                  final next =
                      (device.targetTemperature + 0.5).clamp(16.0, 30.0);
                  _sendCommand(DeviceCommandType.setTargetTemperature, next);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: modes.map((mode) {
              final isSelected = _selectedAcMode == mode;
              return ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text(mode),
                selected: isSelected,
                selectedColor: AppColors.cyan.withValues(alpha: 0.25),
                backgroundColor: AppColors.surfaceElevated,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.cyan : AppColors.surfaceBorder,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedAcMode = mode);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 4. Socket / Outlet Controls
  Widget _buildSocketControls(SmartDevice device) {
    final watts = device.isOn
        ? (device.powerUsageWatts > 0 ? device.powerUsageWatts : 124.0)
        : 0.0;
    const energyKwh = 1.85;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Power & Energy',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: device.isOn,
                activeThumbColor: AppColors.green,
                onChanged: (val) =>
                    _sendCommand(DeviceCommandType.setPower, val),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE POWER',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${watts.toStringAsFixed(1)} W',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ENERGY TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '$energyKwh kWh',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Daily Budget (Target 5.0 kWh)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (energyKwh / 5.0).clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  // 5. Curtain Controls
  Widget _buildCurtainControls(SmartDevice device) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Curtain Position',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${device.position}% Open',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            slider: true,
            label: '${device.name} position',
            value: '${device.position}%',
            child: SizedBox(
              height: 48,
              child: Slider(
                value: device.position.toDouble(),
                min: 0,
                max: 100,
                onChanged: (val) {
                  setState(() {
                    _localDevice = _localDevice.copyWith(position: val.round());
                  });
                },
                onChangeEnd: (val) =>
                    _sendCommand(DeviceCommandType.setPosition, val.round()),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  label: const Text('Open'),
                  onPressed: () =>
                      _sendCommand(DeviceCommandType.setPosition, 100),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.pause_rounded, size: 16),
                  label: const Text('Stop'),
                  onPressed: () => _sendCommand(
                      DeviceCommandType.setPosition, device.position),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  label: const Text('Close'),
                  onPressed: () =>
                      _sendCommand(DeviceCommandType.setPosition, 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Smart Lock Controls
  Widget _buildLockControls(SmartDevice device) {
    final isLocked = device.isLocked;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Smart Lock Security',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          ScaleTransition(
            scale:
                isLocked ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () =>
                  _sendCommand(DeviceCommandType.toggleLock, !isLocked),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLocked
                      ? AppColors.green.withValues(alpha: 0.16)
                      : AppColors.warning.withValues(alpha: 0.16),
                  border: Border.all(
                    color: isLocked ? AppColors.green : AppColors.warning,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isLocked
                          ? AppColors.greenGlow
                          : const Color(0x35FFBE7C),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 44,
                  color: isLocked ? AppColors.green : AppColors.warning,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isLocked
                  ? AppColors.green.withValues(alpha: 0.15)
                  : AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLocked
                    ? AppColors.green.withValues(alpha: 0.4)
                    : AppColors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              isLocked ? 'Locked & Secured' : 'Unlocked',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLocked ? AppColors.green : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Sensor Controls
  Widget _buildSensorControls(SmartDevice device) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Environment Readout',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.battery_full_rounded,
                      color: AppColors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    '88%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.thermostat_outlined,
                          color: AppColors.warning, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        '${device.currentTemperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Temperature',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.water_drop_outlined,
                          color: AppColors.cyan, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        '${device.currentHumidity.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Humidity',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.sentiment_satisfied_alt_rounded,
                    color: AppColors.green, size: 18),
                SizedBox(width: 8),
                Text(
                  'Comfort Rating: Optimal (Normal air index)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 8. Security Controls
  Widget _buildSecurityControls(SmartDevice device) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Perimeter Security System',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            device.isOn ? Icons.shield_rounded : Icons.shield_outlined,
            size: 64,
            color: device.isOn ? AppColors.green : AppColors.muted,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                _sendCommand(DeviceCommandType.setPower, !device.isOn),
            style: ElevatedButton.styleFrom(
              backgroundColor: device.isOn ? AppColors.danger : AppColors.green,
            ),
            child: Text(device.isOn ? 'Disarm Security' : 'Arm Security'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(SmartDevice device) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow('Identifier', device.id),
          _infoRow('Type', device.type.name.toUpperCase()),
          _infoRow('Room Assignment', device.roomId),
          _infoRow('Protocol', 'MQTT / BLE Hybrid'),
          _infoRow('Last Status Synced', 'Updated just now'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _deviceIcon(SmartDevice device) {
    if (device.customIcon != null) {
      switch (device.customIcon) {
        case 'bulb':
          return Icons.lightbulb_rounded;
        case 'desk_lamp':
          return Icons.desk_rounded;
        case 'ceiling_light':
          return Icons.wb_incandescent_rounded;
        case 'fan':
          return Icons.mode_fan_off_outlined;
        case 'ac_unit':
          return Icons.ac_unit_rounded;
        case 'power':
          return Icons.power_rounded;
        case 'lock':
          return Icons.lock_rounded;
        case 'window':
          return Icons.curtains_rounded;
        case 'sensor':
          return Icons.sensors_rounded;
      }
    }
    switch (device.type) {
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
}
