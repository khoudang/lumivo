import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_config.dart';
import '../../../services/storage/home_persistence_manager.dart';
import '../../home/state/homes_notifier.dart';

class DashboardConfigNotifier extends StateNotifier<DashboardConfig> {
  DashboardConfigNotifier({
    required String homeId,
    required HomePersistenceManager persistenceManager,
    DashboardConfig? initialConfig,
  })  : _homeId = homeId,
        _persistenceManager = persistenceManager,
        super(initialConfig ?? persistenceManager.getDashboardConfig(homeId));

  final String _homeId;
  final HomePersistenceManager _persistenceManager;

  String get homeId => _homeId;

  void reorderSections(int oldIndex, int newIndex) {
    var toIndex = newIndex;
    if (oldIndex < toIndex) {
      toIndex -= 1;
    }
    if (oldIndex < 0 || oldIndex >= state.sectionOrder.length) return;
    if (toIndex < 0 || toIndex >= state.sectionOrder.length) return;

    final updated = List<DashboardSection>.from(state.sectionOrder);
    final moved = updated.removeAt(oldIndex);
    updated.insert(toIndex, moved);
    state = state.copyWith(sectionOrder: updated);
  }

  void toggleSectionVisibility(DashboardSection section, bool isVisible) {
    final updated = Map<DashboardSection, bool>.from(state.visibleSections);
    updated[section] = isVisible;
    state = state.copyWith(visibleSections: updated);
  }

  Future<void> resetToDefaults() async {
    final defaults = DashboardConfig.defaultFor(_homeId);
    state = defaults;
    await saveLayout();
  }

  Future<void> saveLayout() async {
    await _persistenceManager.saveDashboardConfig(state);
  }
}

final dashboardEditModeProvider = StateProvider<bool>((ref) => false);
final isDashboardEditModeProvider = dashboardEditModeProvider;

final dashboardConfigProvider =
    StateNotifierProvider<DashboardConfigNotifier, DashboardConfig>((ref) {
  final currentHome = ref.watch(currentHomeProvider);
  final persistence = ref.watch(homePersistenceProvider);
  return DashboardConfigNotifier(
    homeId: currentHome.id,
    persistenceManager: persistence,
  );
});
