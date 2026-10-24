import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../state/automation_providers.dart';
import 'scene_preview_dialog.dart';

class AutomationBuilderWizard extends ConsumerStatefulWidget {
  const AutomationBuilderWizard({super.key});

  @override
  ConsumerState<AutomationBuilderWizard> createState() =>
      _AutomationBuilderWizardState();
}

class _AutomationBuilderWizardState
    extends ConsumerState<AutomationBuilderWizard> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Smart Ambient Rule');

  TriggerType _triggerType = TriggerType.schedule;

  // WHEN: Schedule
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

  // IF: Condition
  bool _conditionEnabled = true;
  String _conditionProperty = 'temperature';
  ComparisonOperator _conditionOperator = ComparisonOperator.greaterThan;
  double _conditionValue = 28.0;

  // THEN: Actions
  final Set<String> _selectedDeviceIds = {'light-1'};
  DeviceCommandType _actionCommand = DeviceCommandType.setPower;
  bool _actionPower = true;
  double _actionTemp = 24.0;
  int _actionBrightness = 80;

  // Validation
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _applyTemplate(String templateName) {
    setState(() {
      _validationError = null;
      switch (templateName) {
        case 'morning':
          _nameController.text = 'Good Morning';
          _triggerType = TriggerType.schedule;
          _selectedTime = const TimeOfDay(hour: 7, minute: 0);
          _conditionEnabled = true;
          _conditionProperty = 'temperature';
          _conditionOperator = ComparisonOperator.greaterThan;
          _conditionValue = 24.0;
          _actionCommand = DeviceCommandType.setPower;
          _actionPower = true;
          _selectedDeviceIds
            ..clear()
            ..addAll(['light-1', 'ac-1', 'curtain-1']);
          break;
        case 'movie':
          _nameController.text = 'Movie Time';
          _triggerType = TriggerType.schedule;
          _selectedTime = const TimeOfDay(hour: 20, minute: 0);
          _conditionEnabled = true;
          _conditionProperty = 'temperature';
          _conditionOperator = ComparisonOperator.greaterThan;
          _conditionValue = 22.0;
          _actionCommand = DeviceCommandType.setBrightness;
          _actionBrightness = 20;
          _selectedDeviceIds
            ..clear()
            ..addAll(['light-1', 'ac-1']);
          break;
        case 'away':
          _nameController.text = 'Away';
          _triggerType = TriggerType.schedule;
          _selectedTime = const TimeOfDay(hour: 8, minute: 30);
          _conditionEnabled = false;
          _actionCommand = DeviceCommandType.setPower;
          _actionPower = false;
          _selectedDeviceIds
            ..clear()
            ..addAll(['light-1', 'ac-1', 'fan-1']);
          break;
        case 'night':
          _nameController.text = 'Night Routine';
          _triggerType = TriggerType.schedule;
          _selectedTime = const TimeOfDay(hour: 23, minute: 0);
          _conditionEnabled = true;
          _conditionProperty = 'temperature';
          _conditionOperator = ComparisonOperator.greaterThan;
          _conditionValue = 26.0;
          _actionCommand = DeviceCommandType.setPower;
          _actionPower = false;
          _selectedDeviceIds
            ..clear()
            ..addAll(['light-1', 'fan-1']);
          break;
      }
    });
  }

  List<DeviceAction> _buildActions() {
    final Object value;
    switch (_actionCommand) {
      case DeviceCommandType.setPower:
        value = _actionPower;
        break;
      case DeviceCommandType.setBrightness:
        value = _actionBrightness;
        break;
      case DeviceCommandType.setTargetTemperature:
        value = _actionTemp;
        break;
      case DeviceCommandType.setPosition:
        value = 100;
        break;
      case DeviceCommandType.setLock:
      case DeviceCommandType.toggleLock:
        value = true;
        break;
    }

    return _selectedDeviceIds
        .map(
          (id) => DeviceAction(
            deviceId: id,
            commandType: _actionCommand,
            value: value,
          ),
        )
        .toList();
  }

  void _saveRule() {
    final name = _nameController.text.trim();
    final l10n = ref.read(appLocalizationsProvider);

    if (name.isEmpty || _selectedDeviceIds.isEmpty) {
      setState(() {
        _validationError = l10n.ruleValidationError;
      });
      return;
    }

    setState(() => _validationError = null);

    final actions = _buildActions();
    final newRule = AutomationRule(
      id: 'rule-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      isEnabled: true,
      triggerType: _triggerType,
      timeOfDay: _triggerType == TriggerType.schedule
          ? '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'
          : null,
      daysOfWeek: _selectedDays.toList()..sort(),
      sensorDeviceId:
          _triggerType == TriggerType.sensorThreshold ? 'sensor-1' : null,
      sensorProperty: _conditionProperty,
      operator: _conditionOperator,
      thresholdValue: _conditionValue,
      actions: actions,
    );

    ref.read(automationRulesProvider.notifier).addRule(newRule);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Automation "$name" created successfully!'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  void _openScenePreview() {
    final actions = _buildActions();
    ScenePreviewDialog.show(
      context,
      actions: actions,
      title: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Scene Preview',
    );
  }

  String _generateHumanSummary(AppLocalizations l10n) {
    // 1. WHEN
    final String whenPart;
    if (_triggerType == TriggerType.schedule) {
      final hourStr = _selectedTime.hour.toString().padLeft(2, '0');
      final minStr = _selectedTime.minute.toString().padLeft(2, '0');
      whenPart =
          'WHEN: At $hourStr:$minStr (${_selectedDays.length} days/week)';
    } else if (_triggerType == TriggerType.sensorThreshold) {
      final op = _conditionOperator == ComparisonOperator.greaterThan
          ? '>'
          : _conditionOperator == ComparisonOperator.lessThan
              ? '<'
              : '=';
      whenPart =
          'WHEN: Sensor $_conditionProperty $op ${_conditionValue.toStringAsFixed(0)}°C';
    } else {
      whenPart = 'WHEN: Device state change detected';
    }

    // 2. IF
    final String ifPart;
    if (_conditionEnabled) {
      final op = _conditionOperator == ComparisonOperator.greaterThan
          ? '>'
          : _conditionOperator == ComparisonOperator.lessThan
              ? '<'
              : '=';
      ifPart =
          'IF: $_conditionProperty $op ${_conditionValue.toStringAsFixed(0)}°C';
    } else {
      ifPart = 'IF: Always true';
    }

    // 3. THEN
    final String cmdStr;
    switch (_actionCommand) {
      case DeviceCommandType.setPower:
        cmdStr = _actionPower ? 'Turn ON' : 'Turn OFF';
        break;
      case DeviceCommandType.setBrightness:
        cmdStr = 'Set Brightness to $_actionBrightness%';
        break;
      case DeviceCommandType.setTargetTemperature:
        cmdStr =
            'Set Target Temperature to ${_actionTemp.toStringAsFixed(0)}°C';
        break;
      case DeviceCommandType.setPosition:
        cmdStr = 'Open Curtains';
        break;
      case DeviceCommandType.setLock:
      case DeviceCommandType.toggleLock:
        cmdStr = 'Lock Security Door';
        break;
    }
    final thenPart =
        'THEN: $cmdStr on ${_selectedDeviceIds.length} target devices';

    return '$whenPart\n$ifPart\n$thenPart';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final allDevices = devicesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          l10n.automationBuilder,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('preview_scene_button'),
            tooltip: l10n.previewScene,
            icon: const Icon(Icons.visibility_rounded, color: AppColors.cyan),
            onPressed: _openScenePreview,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            // Validation Error Banner
            if (_validationError != null) ...[
              Container(
                key: const Key('automation_validation_error'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Quick Starter Templates
            Text(
              'STARTER TEMPLATES',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _templateCard(
                      'morning',
                      l10n.templateMorning,
                      Icons.wb_sunny_rounded,
                      AppColors.warning,
                      const Key('template_morning_card')),
                  const SizedBox(width: 10),
                  _templateCard(
                      'movie',
                      l10n.templateMovie,
                      Icons.movie_rounded,
                      AppColors.cyan,
                      const Key('template_movie_card')),
                  const SizedBox(width: 10),
                  _templateCard('away', l10n.templateAway, Icons.logout_rounded,
                      AppColors.primary, const Key('template_away_card')),
                  const SizedBox(width: 10),
                  _templateCard(
                      'night',
                      l10n.templateNight,
                      Icons.bedtime_rounded,
                      const Color(0xFFB388FF),
                      const Key('template_night_card')),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Automation Name
            Text(
              'AUTOMATION NAME',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('automation_name_input'),
              controller: _nameController,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                hintText: 'e.g. Evening Ambient Mood',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // WHEN Trigger Section
            _buildSectionHeader(
                '1', l10n.whenTrigger, const Key('when_trigger_section')),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTriggerChip(TriggerType.schedule, 'Schedule',
                    Icons.schedule_rounded, const Key('trigger_type_schedule')),
                const SizedBox(width: 8),
                _buildTriggerChip(TriggerType.sensorThreshold, 'Sensor',
                    Icons.thermostat_rounded, const Key('trigger_type_sensor')),
                const SizedBox(width: 8),
                _buildTriggerChip(TriggerType.deviceState, 'Device',
                    Icons.sensors_rounded, const Key('trigger_type_device')),
              ],
            ),
            const SizedBox(height: 12),
            if (_triggerType == TriggerType.schedule)
              _buildScheduleTriggerControls(),

            const SizedBox(height: 24),

            // IF Condition Section
            _buildSectionHeader(
                '2', l10n.ifCondition, const Key('if_condition_section')),
            const SizedBox(height: 12),
            _buildIfConditionControls(),

            const SizedBox(height: 24),

            // THEN Action Section
            _buildSectionHeader(
                '3', l10n.thenAction, const Key('then_action_section')),
            const SizedBox(height: 12),
            _buildThenActionControls(allDevices),

            const SizedBox(height: 24),

            // Automation Summary Card
            Container(
              key: const Key('automation_summary_card'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35)),
                boxShadow: AppShadows.cardGlow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.summarize_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.automationSummary,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _generateHumanSummary(l10n),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons: Save & Preview
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.cyan,
                      side: const BorderSide(color: AppColors.cyan),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _openScenePreview,
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.previewScene),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('save_automation_rule_button'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saveRule,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.save),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateCard(
      String id, String label, IconData icon, Color color, Key key) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(16),
      onTap: () => _applyTemplate(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String stepNum, String title, Key key) {
    return Row(
      key: key,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNum,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
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
    );
  }

  Widget _buildTriggerChip(
      TriggerType type, String label, IconData icon, Key key) {
    final isSelected = _triggerType == type;
    return Expanded(
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _triggerType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 14,
                    color: isSelected ? Colors.white : AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleTriggerControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Time: '
              '${_selectedTime.hour.toString().padLeft(2, '0')}:'
              '${_selectedTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (picked != null) {
                setState(() => _selectedTime = picked);
              }
            },
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Change'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIfConditionControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Enable Condition Check',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              Switch(
                key: const Key('if_condition_toggle'),
                value: _conditionEnabled,
                activeTrackColor: AppColors.primary,
                onChanged: (val) => setState(() => _conditionEnabled = val),
              ),
            ],
          ),
          if (_conditionEnabled) ...[
            const Divider(color: AppColors.surfaceBorder, height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _conditionProperty,
                      dropdownColor: AppColors.surfaceElevated,
                      items: const [
                        DropdownMenuItem(
                            value: 'temperature',
                            child: Text('Temp (°C)',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'humidity',
                            child: Text('Humidity (%)',
                                overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(
                          () => _conditionProperty = v ?? 'temperature'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ComparisonOperator>(
                    key: const Key('condition_operator_dropdown'),
                    value: _conditionOperator,
                    dropdownColor: AppColors.surfaceElevated,
                    items: const [
                      DropdownMenuItem(
                          value: ComparisonOperator.greaterThan,
                          child: Text('>')),
                      DropdownMenuItem(
                          value: ComparisonOperator.lessThan, child: Text('<')),
                      DropdownMenuItem(
                          value: ComparisonOperator.equals, child: Text('=')),
                    ],
                    onChanged: (v) => setState(() => _conditionOperator =
                        v ?? ComparisonOperator.greaterThan),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 55,
                  child: TextField(
                    key: const Key('condition_value_input'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _conditionValue.toStringAsFixed(0),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (val != null) {
                        setState(() => _conditionValue = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThenActionControls(List<SmartDevice> devices) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command selector
          Row(
            children: [
              const Text('Action:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DeviceCommandType>(
                    key: const Key('action_command_dropdown'),
                    isExpanded: true,
                    value: _actionCommand,
                    dropdownColor: AppColors.surfaceElevated,
                    items: const [
                      DropdownMenuItem(
                          value: DeviceCommandType.setPower,
                          child: Text('Power (ON/OFF)')),
                      DropdownMenuItem(
                          value: DeviceCommandType.setBrightness,
                          child: Text('Set Brightness')),
                      DropdownMenuItem(
                          value: DeviceCommandType.setTargetTemperature,
                          child: Text('Set Temperature')),
                    ],
                    onChanged: (v) => setState(
                        () => _actionCommand = v ?? DeviceCommandType.setPower),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Command specific value control
          if (_actionCommand == DeviceCommandType.setPower)
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Turn ON'),
                  selected: _actionPower,
                  onSelected: (s) => setState(() => _actionPower = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Turn OFF'),
                  selected: !_actionPower,
                  onSelected: (s) => setState(() => _actionPower = false),
                ),
              ],
            )
          else if (_actionCommand == DeviceCommandType.setBrightness)
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _actionBrightness.toDouble(),
                    min: 0,
                    max: 100,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _actionBrightness = v.round()),
                  ),
                ),
                Text('$_actionBrightness%',
                    style: const TextStyle(color: AppColors.textPrimary)),
              ],
            )
          else if (_actionCommand == DeviceCommandType.setTargetTemperature)
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _actionTemp,
                    min: 16,
                    max: 30,
                    activeColor: AppColors.cyan,
                    onChanged: (v) => setState(() => _actionTemp = v),
                  ),
                ),
                Text('${_actionTemp.toStringAsFixed(0)}°C',
                    style: const TextStyle(color: AppColors.textPrimary)),
              ],
            ),

          const Divider(color: AppColors.surfaceBorder, height: 20),

          // Multi-device target picker
          const Text('Target Devices:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final dev in devices)
                FilterChip(
                  key: Key('action_device_checkbox_${dev.id}'),
                  label: Text(dev.name),
                  selected: _selectedDeviceIds.contains(dev.id),
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.primary,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDeviceIds.add(dev.id);
                      } else {
                        _selectedDeviceIds.remove(dev.id);
                      }
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
