import 'package:flutter_riverpod/flutter_riverpod.dart';

class DemoLabState {
  const DemoLabState({
    required this.virtualTime,
    this.speedMultiplier = 1,
    this.ambientTemperature = 26.5,
    this.ambientHumidity = 65.0,
    this.isMqttConnected = true,
  });

  final DateTime virtualTime;
  final int speedMultiplier;
  final double ambientTemperature;
  final double ambientHumidity;
  final bool isMqttConnected;

  DemoLabState copyWith({
    DateTime? virtualTime,
    int? speedMultiplier,
    double? ambientTemperature,
    double? ambientHumidity,
    bool? isMqttConnected,
  }) {
    return DemoLabState(
      virtualTime: virtualTime ?? this.virtualTime,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      ambientTemperature: ambientTemperature ?? this.ambientTemperature,
      ambientHumidity: ambientHumidity ?? this.ambientHumidity,
      isMqttConnected: isMqttConnected ?? this.isMqttConnected,
    );
  }
}

class DemoLabNotifier extends StateNotifier<DemoLabState> {
  DemoLabNotifier()
      : super(
          DemoLabState(
            virtualTime: DateTime(2026, 10, 20, 8, 30),
          ),
        );

  void setSpeedMultiplier(int mult) {
    state = state.copyWith(speedMultiplier: mult);
  }

  void advanceHour() {
    state = state.copyWith(
      virtualTime: state.virtualTime.add(const Duration(hours: 1)),
    );
  }

  void jumpToTime(int hour, int minute) {
    final now = state.virtualTime;
    state = state.copyWith(
      virtualTime: DateTime(now.year, now.month, now.day, hour, minute),
    );
  }

  void setAmbientTemperature(double temp) {
    state = state.copyWith(ambientTemperature: temp);
  }

  void setAmbientHumidity(double hum) {
    state = state.copyWith(ambientHumidity: hum);
  }

  void toggleMqttConnection() {
    state = state.copyWith(isMqttConnected: !state.isMqttConnected);
  }

  void reset() {
    state = DemoLabState(
      virtualTime: DateTime(2026, 10, 20, 8, 30),
    );
  }
}

final demoLabProvider =
    StateNotifierProvider<DemoLabNotifier, DemoLabState>((ref) {
  return DemoLabNotifier();
});
