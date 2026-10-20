import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/simulation/simulation_engine.dart';

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
  DemoLabNotifier([SimulationEngine? simEngine])
      : _simEngine = simEngine,
        super(
          DemoLabState(
            virtualTime: DateTime(2026, 10, 20, 8, 30),
          ),
        );

  final SimulationEngine? _simEngine;

  void setSpeedMultiplier(int mult) {
    state = state.copyWith(speedMultiplier: mult);
    _simEngine?.setMultiplier(mult.toDouble());
  }

  void advanceHour() {
    final next = state.virtualTime.add(const Duration(hours: 1));
    state = state.copyWith(virtualTime: next);
    _simEngine?.advanceTime(const Duration(hours: 1));
  }

  void jumpToTime(int hour, int minute) {
    final now = state.virtualTime;
    final next = DateTime(now.year, now.month, now.day, hour, minute);
    state = state.copyWith(virtualTime: next);
    _simEngine?.setVirtualTime(next);
  }

  void setAmbientTemperature(double temp) {
    state = state.copyWith(ambientTemperature: temp);
    _simEngine?.forceAmbientTemperature(temp);
  }

  void setAmbientHumidity(double hum) {
    state = state.copyWith(ambientHumidity: hum);
    _simEngine?.forceAmbientHumidity(hum);
  }

  void toggleMqttConnection() {
    state = state.copyWith(isMqttConnected: !state.isMqttConnected);
  }

  void reset() {
    state = DemoLabState(
      virtualTime: DateTime(2026, 10, 20, 8, 30),
    );
    _simEngine?.reset();
  }
}

final demoLabProvider =
    StateNotifierProvider<DemoLabNotifier, DemoLabState>((ref) {
  return DemoLabNotifier();
});
