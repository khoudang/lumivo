import 'device_command.dart';

enum TriggerType { schedule, sensorThreshold, deviceState }

enum ComparisonOperator { greaterThan, lessThan, equals }

class DeviceAction {
  const DeviceAction({
    required this.deviceId,
    required this.commandType,
    required this.value,
  });

  final String deviceId;
  final DeviceCommandType commandType;
  final Object value;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'commandType': commandType.name,
        'value': value,
      };

  factory DeviceAction.fromJson(Map<String, dynamic> json) => DeviceAction(
        deviceId: json['deviceId'] as String,
        commandType: DeviceCommandType.values.firstWhere(
          (e) => e.name == json['commandType'],
          orElse: () => DeviceCommandType.setPower,
        ),
        value: json['value'] as Object,
      );
}

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.triggerType,
    this.timeOfDay,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.sensorDeviceId,
    this.sensorProperty = 'temperature',
    this.operator = ComparisonOperator.greaterThan,
    this.thresholdValue = 28.0,
    required this.actions,
    this.lastExecutedAt,
  });

  final String id;
  final String name;
  final bool isEnabled;
  final TriggerType triggerType;
  final String? timeOfDay;
  final List<int> daysOfWeek;
  final String? sensorDeviceId;
  final String sensorProperty;
  final ComparisonOperator operator;
  final double thresholdValue;
  final List<DeviceAction> actions;
  final DateTime? lastExecutedAt;

  AutomationRule copyWith({
    String? id,
    String? name,
    bool? isEnabled,
    TriggerType? triggerType,
    String? timeOfDay,
    List<int>? daysOfWeek,
    String? sensorDeviceId,
    String? sensorProperty,
    ComparisonOperator? operator,
    double? thresholdValue,
    List<DeviceAction>? actions,
    DateTime? lastExecutedAt,
  }) =>
      AutomationRule(
        id: id ?? this.id,
        name: name ?? this.name,
        isEnabled: isEnabled ?? this.isEnabled,
        triggerType: triggerType ?? this.triggerType,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        sensorDeviceId: sensorDeviceId ?? this.sensorDeviceId,
        sensorProperty: sensorProperty ?? this.sensorProperty,
        operator: operator ?? this.operator,
        thresholdValue: thresholdValue ?? this.thresholdValue,
        actions: actions ?? this.actions,
        lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isEnabled': isEnabled,
        'triggerType': triggerType.name,
        'timeOfDay': timeOfDay,
        'daysOfWeek': daysOfWeek,
        'sensorDeviceId': sensorDeviceId,
        'sensorProperty': sensorProperty,
        'operator': operator.name,
        'thresholdValue': thresholdValue,
        'actions': actions.map((a) => a.toJson()).toList(),
        'lastExecutedAt': lastExecutedAt?.toIso8601String(),
      };

  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
        id: json['id'] as String,
        name: json['name'] as String,
        isEnabled: json['isEnabled'] as bool? ?? true,
        triggerType: TriggerType.values.firstWhere(
          (e) => e.name == json['triggerType'],
          orElse: () => TriggerType.schedule,
        ),
        timeOfDay: json['timeOfDay'] as String?,
        daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [1, 2, 3, 4, 5, 6, 7],
        sensorDeviceId: json['sensorDeviceId'] as String?,
        sensorProperty: json['sensorProperty'] as String? ?? 'temperature',
        operator: ComparisonOperator.values.firstWhere(
          (e) => e.name == json['operator'],
          orElse: () => ComparisonOperator.greaterThan,
        ),
        thresholdValue: (json['thresholdValue'] as num?)?.toDouble() ?? 28.0,
        actions: (json['actions'] as List<dynamic>?)
                ?.map((e) => DeviceAction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        lastExecutedAt: json['lastExecutedAt'] != null
            ? DateTime.tryParse(json['lastExecutedAt'] as String)
            : null,
      );
}

class Scene {
  const Scene({
    required this.id,
    required this.name,
    this.iconName = 'auto_awesome',
    required this.actions,
  });

  final String id;
  final String name;
  final String iconName;
  final List<DeviceAction> actions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconName': iconName,
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  factory Scene.fromJson(Map<String, dynamic> json) => Scene(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['iconName'] as String? ?? 'auto_awesome',
        actions: (json['actions'] as List<dynamic>?)
                ?.map((e) => DeviceAction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
