enum ActivitySeverity { info, warning, success, alert }

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    this.deviceId,
    this.roomId,
    this.homeId,
    this.severity = ActivitySeverity.info,
    this.source = 'system',
  });

  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? deviceId;
  final String? roomId;
  final String? homeId;
  final ActivitySeverity severity;
  final String source; // "manual", "automation", "simulation", "system"

  ActivityEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? timestamp,
    String? deviceId,
    String? roomId,
    String? homeId,
    ActivitySeverity? severity,
    String? source,
  }) =>
      ActivityEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        timestamp: timestamp ?? this.timestamp,
        deviceId: deviceId ?? this.deviceId,
        roomId: roomId ?? this.roomId,
        homeId: homeId ?? this.homeId,
        severity: severity ?? this.severity,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'deviceId': deviceId,
        'roomId': roomId,
        'homeId': homeId,
        'severity': severity.name,
        'source': source,
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        deviceId: json['deviceId'] as String?,
        roomId: json['roomId'] as String?,
        homeId: json['homeId'] as String?,
        severity: ActivitySeverity.values.firstWhere(
          (e) => e.name == json['severity'],
          orElse: () => ActivitySeverity.info,
        ),
        source: json['source'] as String? ?? 'system',
      );
}
