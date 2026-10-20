import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/theme/app_theme.dart';
import '../state/automation_providers.dart';

class CreateAutomationScreen extends ConsumerStatefulWidget {
  const CreateAutomationScreen({super.key});

  @override
  ConsumerState<CreateAutomationScreen> createState() =>
      _CreateAutomationScreenState();
}

class _CreateAutomationScreenState
    extends ConsumerState<CreateAutomationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Evening Ambient');

  TriggerType _triggerType = TriggerType.schedule;

  // Schedule Trigger
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 30);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

  // Sensor Trigger
  String _selectedSensorProperty = 'temperature';
  ComparisonOperator _selectedOperator = ComparisonOperator.greaterThan;
  double _thresholdValue = 28.0;

  // Action
  String? _selectedDeviceId;
  DeviceCommandType _selectedCommand = DeviceCommandType.setPower;
  bool _powerValue = true;
  double _targetTempValue = 24.0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveRule() {
    if (!_formKey.currentState!.validate()) return;

    final targetId = _selectedDeviceId ?? 'light-1';
    final Object actionValue;
    switch (_selectedCommand) {
      case DeviceCommandType.setPower:
        actionValue = _powerValue;
        break;
      case DeviceCommandType.setTargetTemperature:
        actionValue = _targetTempValue;
        break;
      case DeviceCommandType.setBrightness:
        actionValue = 80;
        break;
      case DeviceCommandType.setPosition:
        actionValue = 100;
        break;
      case DeviceCommandType.setLock:
      case DeviceCommandType.toggleLock:
        actionValue = true;
        break;
    }

    final newRule = AutomationRule(
      id: 'rule-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      isEnabled: true,
      triggerType: _triggerType,
      timeOfDay: _triggerType == TriggerType.schedule
          ? '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'
          : null,
      daysOfWeek: _selectedDays.toList()..sort(),
      sensorDeviceId:
          _triggerType == TriggerType.sensorThreshold ? 'sensor-1' : null,
      sensorProperty: _selectedSensorProperty,
      operator: _selectedOperator,
      thresholdValue: _thresholdValue,
      actions: [
        DeviceAction(
          deviceId: targetId,
          commandType: _selectedCommand,
          value: actionValue,
        ),
      ],
    );

    ref.read(automationRulesProvider.notifier).addRule(newRule);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rule "${newRule.name}" created successfully!'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final devices = devicesAsync.valueOrNull ?? const [];

    if (_selectedDeviceId == null && devices.isNotEmpty) {
      _selectedDeviceId = devices.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Automation Rule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Step 1: Rule Name
              _buildSectionHeader('1', 'Rule Details'),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('automation_name_input'),
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Rule Name',
                  hintText: 'e.g. Good Night, Balcony Cool Down',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a rule name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Step 2: Trigger Type
              _buildSectionHeader('2', 'When this happens... (Trigger)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTriggerTypeCard(
                      type: TriggerType.schedule,
                      icon: Icons.schedule_rounded,
                      title: 'Schedule',
                      subtitle: 'Time of day & days',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTriggerTypeCard(
                      type: TriggerType.sensorThreshold,
                      icon: Icons.sensors_rounded,
                      title: 'Sensor',
                      subtitle: 'Threshold condition',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_triggerType == TriggerType.schedule)
                _buildScheduleTriggerConfig()
              else
                _buildSensorTriggerConfig(),

              const SizedBox(height: 28),

              // Step 3: Action
              _buildSectionHeader('3', 'Then do this... (Action)'),
              const SizedBox(height: 12),
              _buildActionConfig(devices),

              const SizedBox(height: 36),

              // Save Button
              ElevatedButton.icon(
                key: const Key('save_automation_button'),
                onPressed: _saveRule,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save Automation Rule'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerTypeCard({
    required TriggerType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _triggerType == type;

    return InkWell(
      onTap: () => setState(() => _triggerType = type),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.muted,
              size: 26,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTriggerConfig() {
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trigger Time',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (picked != null) {
                    setState(() => _selectedTime = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Repeat Days',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayIndex = index + 1;
              final isSelected = _selectedDays.contains(dayIndex);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      if (_selectedDays.length > 1) {
                        _selectedDays.remove(dayIndex);
                      }
                    } else {
                      _selectedDays.add(dayIndex);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Text(
                    dayNames[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorTriggerConfig() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSensorProperty,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: const [
                    DropdownMenuItem(
                      value: 'temperature',
                      child: Text('Temperature (°C)'),
                    ),
                    DropdownMenuItem(
                      value: 'humidity',
                      child: Text('Humidity (%)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSensorProperty = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ComparisonOperator>(
                  initialValue: _selectedOperator,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(labelText: 'Operator'),
                  items: const [
                    DropdownMenuItem(
                      value: ComparisonOperator.greaterThan,
                      child: Text('> Greater Than'),
                    ),
                    DropdownMenuItem(
                      value: ComparisonOperator.lessThan,
                      child: Text('< Less Than'),
                    ),
                    DropdownMenuItem(
                      value: ComparisonOperator.equals,
                      child: Text('= Equals'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedOperator = val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Threshold Value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _selectedSensorProperty == 'temperature'
                    ? '${_thresholdValue.toStringAsFixed(1)} °C'
                    : '${_thresholdValue.toStringAsFixed(0)} %',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          Slider(
            value: _thresholdValue,
            min: _selectedSensorProperty == 'temperature' ? 10.0 : 20.0,
            max: _selectedSensorProperty == 'temperature' ? 40.0 : 95.0,
            onChanged: (val) => setState(() => _thresholdValue = val),
          ),
        ],
      ),
    );
  }

  Widget _buildActionConfig(List<dynamic> devices) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedDeviceId,
            dropdownColor: AppColors.surfaceElevated,
            decoration: const InputDecoration(labelText: 'Target Device'),
            items: devices.map((d) {
              return DropdownMenuItem<String>(
                value: d.id as String,
                child: Text('${d.name} (${d.roomId})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedDeviceId = val);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DeviceCommandType>(
            initialValue: _selectedCommand,
            dropdownColor: AppColors.surfaceElevated,
            decoration: const InputDecoration(labelText: 'Command'),
            items: const [
              DropdownMenuItem(
                value: DeviceCommandType.setPower,
                child: Text('Turn Power On / Off'),
              ),
              DropdownMenuItem(
                value: DeviceCommandType.setTargetTemperature,
                child: Text('Set Target Temperature'),
              ),
              DropdownMenuItem(
                value: DeviceCommandType.setBrightness,
                child: Text('Set Brightness (80%)'),
              ),
              DropdownMenuItem(
                value: DeviceCommandType.setPosition,
                child: Text('Open Curtain (100%)'),
              ),
              DropdownMenuItem(
                value: DeviceCommandType.setLock,
                child: Text('Engage Lock'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedCommand = val);
            },
          ),
          if (_selectedCommand == DeviceCommandType.setPower) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Power State to Apply',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Switch(
                  value: _powerValue,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _powerValue = val),
                ),
              ],
            ),
          ] else if (_selectedCommand ==
              DeviceCommandType.setTargetTemperature) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Target Temperature',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${_targetTempValue.toStringAsFixed(1)} °C',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
            Slider(
              value: _targetTempValue,
              min: 16.0,
              max: 30.0,
              onChanged: (val) => setState(() => _targetTempValue = val),
            ),
          ],
        ],
      ),
    );
  }
}
