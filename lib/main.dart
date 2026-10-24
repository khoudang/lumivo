import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'services/simulation/simulation_lifecycle_observer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SimulationLifecycleObserver(autoRegister: true);
  runApp(const ProviderScope(child: LumivoApp()));
}
