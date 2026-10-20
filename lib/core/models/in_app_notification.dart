import 'activity_event.dart';

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.severity = ActivitySeverity.info,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final ActivitySeverity severity;

  InAppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    ActivitySeverity? severity,
  }) =>
      InAppNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
        severity: severity ?? this.severity,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'severity': severity.name,
      };

  factory InAppNotification.fromJson(Map<String, dynamic> json) =>
      InAppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
        severity: ActivitySeverity.values.firstWhere(
          (e) => e.name == json['severity'],
          orElse: () => ActivitySeverity.info,
        ),
      );
}
