import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_config.dart';

class DashboardConfigNotifier extends StateNotifier<DashboardConfig> {
  DashboardConfigNotifier([DashboardConfig? initialConfig])
      : super(initialConfig ?? defaultWithAllSections('home-default'));

  static DashboardConfig defaultWithAllSections(String homeId) {
    final base = DashboardConfig.defaultFor(homeId);
    final order = List<DashboardSection>.from(base.sectionOrder);
    if (!order.contains(DashboardSection.demoLab)) {
      order.add(DashboardSection.demoLab);
    }
    final visibility = Map<DashboardSection, bool>.from(base.visibleSections);
    for (final s in DashboardSection.values) {
      visibility.putIfAbsent(s, () => true);
    }
    return base.copyWith(
      sectionOrder: order,
      visibleSections: visibility,
    );
  }

  void reorder(int oldIndex, int newIndex) {
    var adjustedNew = newIndex;
    if (oldIndex < newIndex) {
      adjustedNew -= 1;
    }
    final order = List<DashboardSection>.from(state.sectionOrder);
    final item = order.removeAt(oldIndex);
    order.insert(adjustedNew, item);
    state = state.copyWith(sectionOrder: order);
  }

  void toggleVisibility(DashboardSection section, bool isVisible) {
    final visibility = Map<DashboardSection, bool>.from(state.visibleSections);
    visibility[section] = isVisible;
    state = state.copyWith(visibleSections: visibility);
  }

  void setConfig(DashboardConfig config) {
    state = config;
  }

  void resetToDefaults() {
    state = defaultWithAllSections(state.homeId);
  }
}

final dashboardConfigProvider =
    StateNotifierProvider<DashboardConfigNotifier, DashboardConfig>((ref) {
  return DashboardConfigNotifier();
});
