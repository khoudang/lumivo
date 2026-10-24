enum DashboardSection {
  metrics,
  health,
  favorites,
  quickScenes,
  devices,
  activity,
  demoLab,
}

class DashboardConfig {
  const DashboardConfig({
    required this.homeId,
    required this.sectionOrder,
    required this.visibleSections,
  });

  final String homeId;
  final List<DashboardSection> sectionOrder;
  final Map<DashboardSection, bool> visibleSections;

  bool isVisible(DashboardSection section) => visibleSections[section] ?? true;

  DashboardConfig copyWith({
    String? homeId,
    List<DashboardSection>? sectionOrder,
    Map<DashboardSection, bool>? visibleSections,
  }) =>
      DashboardConfig(
        homeId: homeId ?? this.homeId,
        sectionOrder: sectionOrder ?? List.from(this.sectionOrder),
        visibleSections: visibleSections ?? Map.from(this.visibleSections),
      );

  factory DashboardConfig.defaultFor(String homeId) => DashboardConfig(
        homeId: homeId,
        sectionOrder: const [
          DashboardSection.metrics,
          DashboardSection.health,
          DashboardSection.favorites,
          DashboardSection.quickScenes,
          DashboardSection.devices,
          DashboardSection.activity,
        ],
        visibleSections: const {
          DashboardSection.metrics: true,
          DashboardSection.health: true,
          DashboardSection.favorites: true,
          DashboardSection.quickScenes: true,
          DashboardSection.devices: true,
          DashboardSection.activity: true,
          DashboardSection.demoLab: true,
        },
      );

  Map<String, dynamic> toJson() => {
        'homeId': homeId,
        'sectionOrder': sectionOrder.map((s) => s.name).toList(),
        'visibleSections': visibleSections.map((k, v) => MapEntry(k.name, v)),
      };

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    final homeId = json['homeId'] as String? ?? 'home-default';
    final defaults = DashboardConfig.defaultFor(homeId);

    List<DashboardSection> order = defaults.sectionOrder;
    if (json['sectionOrder'] != null) {
      final list = json['sectionOrder'] as List<dynamic>;
      order = list
          .map((s) => DashboardSection.values.firstWhere(
                (e) => e.name == s,
                orElse: () => DashboardSection.devices,
              ))
          .toSet()
          .toList();
    }

    Map<DashboardSection, bool> visibility = Map.from(defaults.visibleSections);
    if (json['visibleSections'] != null) {
      final map = json['visibleSections'] as Map<String, dynamic>;
      map.forEach((k, v) {
        final sec = DashboardSection.values.firstWhere(
          (e) => e.name == k,
          orElse: () => DashboardSection.devices,
        );
        visibility[sec] = v as bool? ?? true;
      });
    }

    return DashboardConfig(
      homeId: homeId,
      sectionOrder: order,
      visibleSections: visibility,
    );
  }
}
