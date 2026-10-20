import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/activity_event.dart';

final List<ActivityEvent> defaultActivityEvents = [
  ActivityEvent(
    id: 'act-1',
    title: 'AC Target Set to 22°C',
    description: 'Manual temperature override for Living Room AC',
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    deviceId: 'ac-1',
    roomId: 'Living Room',
    severity: ActivitySeverity.info,
    source: 'manual',
  ),
  ActivityEvent(
    id: 'act-2',
    title: 'Morning Routine Fired',
    description: 'Living room light turned on at 72% brightness',
    timestamp: DateTime.now().subtract(const Duration(minutes: 24)),
    deviceId: 'light-1',
    roomId: 'Living Room',
    severity: ActivitySeverity.success,
    source: 'automation',
  ),
  ActivityEvent(
    id: 'act-3',
    title: 'High Temperature Alert: 32.4°C',
    description: 'Balcony ambient sensor threshold exceeded (30.0°C)',
    timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 12)),
    deviceId: 'sensor-1',
    roomId: 'Balcony',
    severity: ActivitySeverity.alert,
    source: 'simulation',
  ),
  ActivityEvent(
    id: 'act-4',
    title: 'Smart Fan Offline Warning',
    description: 'Bedroom Fan connection timed out on local MQTT broker',
    timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
    deviceId: 'fan-2',
    roomId: 'Bedroom',
    severity: ActivitySeverity.warning,
    source: 'system',
  ),
  ActivityEvent(
    id: 'act-5',
    title: 'Smart Lock Secured',
    description: 'Front door deadbolt locked by user command',
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    deviceId: 'lock-1',
    roomId: 'Living Room',
    severity: ActivitySeverity.success,
    source: 'manual',
  ),
];

class ActivityNotifier extends StateNotifier<List<ActivityEvent>> {
  ActivityNotifier([List<ActivityEvent>? initial])
      : super(initial ?? defaultActivityEvents);

  void addEvent(ActivityEvent event) {
    state = [event, ...state];
  }

  void clearEvents() {
    state = const [];
  }

  void reset() {
    state = defaultActivityEvents;
  }
}

final activityProvider =
    StateNotifierProvider<ActivityNotifier, List<ActivityEvent>>((ref) {
  return ActivityNotifier();
});
