import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'services/simulation/simulation_lifecycle_observer.dart';
import 'services/storage/home_persistence_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Providers synchronously seed their state from cachedState. Hydrate once
  // before creating them, otherwise a cold start silently uses demo defaults.
  final persistence = HomePersistenceManager();
  await persistence.loadHomeState();
  SimulationLifecycleObserver(autoRegister: true);
  runApp(ProviderScope(
    overrides: [homePersistenceProvider.overrideWithValue(persistence)],
    child: const LumivoApp(),
  ));
}
