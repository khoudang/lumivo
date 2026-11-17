import '../../search/presentation/device_search_screen.dart';
import 'dashboard_edit_sheet.dart';
import '../../../core/models/dashboard_config.dart';
import '../../health/presentation/smart_home_health_screen.dart';
import '../../lab/presentation/demo_lab_sheet.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../energy/presentation/energy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';

import '../../../core/models/activity_event.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/device_command.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../activity/presentation/activity_screen.dart';
import '../../automation/presentation/automation_screen.dart';
import '../../device_detail/presentation/device_detail_screen.dart';
import '../../notifications/presentation/notifications_sheet.dart';
import '../../notifications/state/notifications_providers.dart';
import '../../onboarding/presentation/add_device_sheet.dart';
import '../../rooms/presentation/rooms_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../widgets/brightness_slider_card.dart';
import '../widgets/device_card.dart';
import '../widgets/room_selector.dart';
import '../widgets/favorites_section.dart';
import '../../home/presentation/home_selector_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ColorScheme get palette => Theme.of(context).colorScheme;

  String room = 'Living Room';
  int selectedTab = 0;
  final Set<String> pending = {};
  int serial = 0;
  final Map<String, double> brightnessDraft = {};

  Future<void> _send(
    SmartDevice device,
    DeviceCommandType type,
    Object value,
  ) async {
    if (pending.contains(device.id)) return;
    setState(() => pending.add(device.id));

    final result = await ref.read(deviceRepositoryProvider).sendCommand(
          DeviceCommand(
            requestId: 'local-${++serial}',
            deviceId: device.id,
            type: type,
            value: value,
          ),
        );

    if (!mounted) return;
    setState(() => pending.remove(device.id));

    if (result.status != CommandStatus.confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Command failed'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _openAddDeviceSheet() {
    AddDeviceSheet.show(
      Navigator.of(context).context,
      onDeviceAdded: (newDevice) {
        final repo = ref.read(deviceRepositoryProvider);
        if (repo is MockDeviceRepository) {
          repo.addDevice(newDevice);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newDevice.name} paired successfully!'),
            backgroundColor: palette.primary,
          ),
        );
      },
    );
  }

  void _runScene(Scene scene) async {
    final l10n = ref.read(appLocalizationsProvider);
    for (final action in scene.actions) {
      await ref.read(deviceRepositoryProvider).sendCommand(
            DeviceCommand(
              requestId: 'scene-${DateTime.now().millisecondsSinceEpoch}',
              deviceId: action.deviceId,
              type: action.commandType,
              value: action.value,
            ),
          );
    }

    ref.read(activityProvider.notifier).addEvent(
          ActivityEvent(
            id: 'act-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Scene "${scene.name}" Triggered',
            description: '${scene.actions.length} commands dispatched',
            timestamp: DateTime.now(),
            severity: ActivitySeverity.success,
            source: 'automation',
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sceneExecuted(scene.name)),
          backgroundColor: palette.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      floatingActionButton: selectedTab == 0
          ? Semantics(
              button: true,
              label: l10n.addDevice,
              child: FloatingActionButton(
                heroTag: 'dashboard_fab',
                key: Key('dashboard_add_device_fab'),
                onPressed: _openAddDeviceSheet,
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                tooltip: l10n.addDevice,
                child: Icon(Icons.add_rounded, size: 28),
              ),
            )
          : null,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: _navigation(l10n),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: selectedTab,
                    children: [
                      // Tab 0: Home
                      devices.when(
                        data: (all) => _home(all, l10n),
                        loading: () => Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, _) => Center(
                          child: Text(
                            'Error: $error',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                      // Tab 1: Rooms
                      Theme(
                          data: AppTheme.dark,
                          child: RoomsScreen(
                            onRoomSelected: (selectedRoom) {
                              setState(() {
                                room = selectedRoom;
                                selectedTab = 0;
                              });
                            },
                          )),
                      // Tab 2: Automation
                      Theme(data: AppTheme.dark, child: AutomationScreen()),
                      // Tab 3: Activity
                      Theme(data: AppTheme.dark, child: ActivityScreen()),
                      // Tab 4: Settings
                      Theme(data: AppTheme.dark, child: SettingsScreen()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _home(List<SmartDevice> all, AppLocalizations l10n) {
    final currentHome = ref.watch(currentHomeProvider);
    final homeDevices = all.where((d) => d.homeId == currentHome.id).toList();
    final allRooms = ref.watch(roomsProvider);
    final homeRoomNames = allRooms
        .where((r) => r.homeId == currentHome.id)
        .map((r) => r.name)
        .toList();
    final rooms = homeRoomNames.isNotEmpty
        ? homeRoomNames
        : ['Living Room', 'Bedroom', 'Kitchen'];
    if (!rooms.contains(room)) {
      room = rooms.first;
    }

    final roomCounts = <String, int>{};
    for (final r in rooms) {
      roomCounts[r] = homeDevices.where((d) => d.roomId == r).length;
    }

    final visible = homeDevices.where((d) => d.roomId == room).toList();
    final dashboardConfig = ref.watch(dashboardConfigProvider);
    // Prioritize operation only for the untouched default composition.
    // A saved user arrangement remains authoritative.
    final sectionOrder = listEquals(dashboardConfig.sectionOrder,
            DashboardConfig.defaultFor(currentHome.id).sectionOrder)
        ? [
            DashboardSection.devices,
            ...dashboardConfig.sectionOrder
                .where((s) => s != DashboardSection.devices)
          ]
        : dashboardConfig.sectionOrder;
    final lights = visible.where((d) => d.type == DeviceType.light).toList();
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 400;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            screenWidth > 600 ? 32 : (screenWidth < 360 ? 14 : 22),
            16,
            screenWidth > 600 ? 32 : (screenWidth < 360 ? 14 : 22),
            24,
          ),
          children: [
            // Identity and tools have independent space on narrow screens.
            Row(children: [
              Text('LUMIVO',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: palette.onSurface)),
              SizedBox(width: 12),
              Expanded(
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('home_app_bar_title_button'),
                        onPressed: () => HomeSelectorSheet.show(
                            Navigator.of(context).context),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                              child: Text(currentHome.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.expand_more_rounded, size: 18),
                        ]),
                      ))),
            ]),
            SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.end, children: [
              if (dashboardConfig.isVisible(DashboardSection.health))
                _buildHealthSection(l10n),
              if (dashboardConfig.isVisible(DashboardSection.demoLab))
                _buildDemoLabSection(l10n),
              // Global Search Button
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: Key('dashboard_search_button'),
                  tooltip: l10n.searchDevices,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.search_rounded,
                    color: palette.onSurface,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeviceSearchScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Edit Dashboard Button
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: Key('dashboard_edit_mode_button'),
                  tooltip: l10n.editDashboard,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.dashboard_customize_outlined,
                    color: palette.onSurface,
                    size: 22,
                  ),
                  onPressed: () => DashboardEditSheet.show(context),
                ),
              ),
              // Notifications Bell with Badge
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Center(
                      child: IconButton(
                        key: Key('dashboard_notifications_button'),
                        tooltip: 'Notifications',
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.notifications_none_rounded,
                          color: palette.onSurface,
                          size: 22,
                        ),
                        onPressed: () => NotificationsSheet.show(
                            Navigator.of(context).context),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: palette.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: l10n.userProfilePreferences,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: InkWell(
                    key: Key('dashboard_profile_button'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(),
                        ),
                      );
                    },
                    child: Center(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: palette.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: palette.onSurface,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            SizedBox(height: 16),

            // Greeting & Date
            Text(
              _dateLabel(),
              style: TextStyle(
                color: palette.onSurfaceVariant.withValues(alpha: .9),
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              l10n.welcomeHome,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: palette.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 6),
            Text(
              currentHome.name,
              style: TextStyle(
                color: palette.onSurfaceVariant,
                fontSize: 13,
              ),
            ),

            SizedBox(height: 18),

            // Dynamic Section Rendering based on DashboardConfig
            for (final section in sectionOrder)
              if (dashboardConfig.isVisible(section) &&
                  section != DashboardSection.health &&
                  section != DashboardSection.demoLab) ...[
                _buildDashboardSection(
                  section,
                  all: homeDevices,
                  visible: visible,
                  lights: lights,
                  screenWidth: screenWidth,
                  isCompact: isCompact,
                  rooms: rooms,
                  roomCounts: roomCounts,
                  l10n: l10n,
                ),
                SizedBox(height: 22),
              ],

            // Status footnote
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: palette.primary,
                  size: 14,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l10n.demoModeFootnote,
                    style: TextStyle(
                      color: palette.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardSection(
    DashboardSection section, {
    required List<SmartDevice> all,
    required List<SmartDevice> visible,
    required List<SmartDevice> lights,
    required double screenWidth,
    required bool isCompact,
    required List<String> rooms,
    required Map<String, int> roomCounts,
    required AppLocalizations l10n,
  }) {
    switch (section) {
      case DashboardSection.metrics:
        return _buildResponsiveMetrics(screenWidth, isCompact, l10n);

      case DashboardSection.health:
        return _buildHealthSection(l10n);

      case DashboardSection.demoLab:
        return _buildDemoLabSection(l10n);

      case DashboardSection.quickScenes:
        return _buildQuickScenesSection(l10n);

      case DashboardSection.favorites:
        return FavoritesSection(
          favoriteDevices: all.where((d) => d.isFavorite).toList()
            ..sort((a, b) => a.favoriteOrder.compareTo(b.favoriteOrder)),
          onReorder: (oldIndex, newIndex) {
            final favorites = all.where((d) => d.isFavorite).toList()
              ..sort((a, b) => a.favoriteOrder.compareTo(b.favoriteOrder));
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final item = favorites.removeAt(oldIndex);
            favorites.insert(newIndex, item);
            final repo = ref.read(deviceRepositoryProvider);
            if (repo is MockDeviceRepository) {
              for (int i = 0; i < favorites.length; i++) {
                repo.updateDevice(favorites[i].copyWith(favoriteOrder: i));
              }
            }
          },
          onDeviceTap: (device) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeviceDetailScreen(device: device),
              ),
            );
          },
          onDeviceToggle: (device) => _send(
            device,
            DeviceCommandType.setPower,
            !device.isOn,
          ),
        );

      case DashboardSection.devices:
        return _buildDevicesSection(
          visible: visible,
          lights: lights,
          screenWidth: screenWidth,
          rooms: rooms,
          roomCounts: roomCounts,
          l10n: l10n,
        );

      case DashboardSection.activity:
        return _buildActivitySection(l10n);
    }
  }

  Widget _buildHealthSection(AppLocalizations l10n) => IconButton(
        key: const Key('dashboard_health_button'),
        tooltip: l10n.healthDashboard,
        icon: Icon(Icons.favorite_border_rounded,
            color: palette.onSurfaceVariant, size: 21),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SmartHomeHealthScreen())),
      );

  Widget _buildDemoLabSection(AppLocalizations l10n) => IconButton(
        key: const Key('dashboard_demo_lab_button'),
        tooltip: l10n.demoLab,
        icon: Icon(Icons.science_outlined,
            color: palette.onSurfaceVariant, size: 21),
        onPressed: () => DemoLabSheet.show(Navigator.of(context).context),
      );

  Widget _buildActivitySection(AppLocalizations l10n) {
    final currentHome = ref.watch(currentHomeProvider);
    final allEvents = ref.watch(activityProvider);
    final recentEvents = allEvents
        .where((e) => e.homeId == null || e.homeId == currentHome.id)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
                child: Text(
              l10n.activityTimeline,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: palette.onSurface,
              ),
            )),
            Spacer(),
            TextButton(
              onPressed: () => setState(() => selectedTab = 3),
              child: Text(l10n.seeAll),
            ),
          ],
        ),
        SizedBox(height: 10),
        if (recentEvents.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.outlineVariant),
            ),
            child: Text(
              l10n.noActivity,
              style: TextStyle(color: palette.onSurfaceVariant, fontSize: 13),
            ),
          )
        else
          for (final ev in recentEvents)
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: palette.primary,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.title,
                          style: TextStyle(
                            color: palette.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ev.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildDevicesSection({
    required List<SmartDevice> visible,
    required List<SmartDevice> lights,
    required double screenWidth,
    required List<String> rooms,
    required Map<String, int> roomCounts,
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room Filter Section
        Text(
          l10n.rooms,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: palette.onSurface,
          ),
        ),
        SizedBox(height: 12),
        RoomSelector(
          rooms: rooms,
          selectedRoom: room,
          onRoomSelected: (selected) => setState(() => room = selected),
          roomDeviceCounts: roomCounts,
        ),

        SizedBox(height: 28),

        // Devices Section Header
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.devices,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: palette.onSurface,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  l10n.devicesCount(visible.length),
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 14),

        // Responsive Device Cards
        _buildResponsiveDeviceGrid(visible, screenWidth),

        // Brightness Control Section
        if (lights.isNotEmpty) ...[
          SizedBox(height: 20),
          for (final light in lights) ...[
            BrightnessSliderCard(
              device: light,
              brightness:
                  brightnessDraft[light.id] ?? light.brightness.toDouble(),
              isBusy: pending.contains(light.id),
              onChanged: (value) =>
                  setState(() => brightnessDraft[light.id] = value),
              onChangeEnd: (value) async {
                await _send(
                  light,
                  DeviceCommandType.setBrightness,
                  value.round(),
                );
                if (mounted) {
                  setState(() => brightnessDraft.remove(light.id));
                }
              },
            ),
            SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildQuickScenesSection(AppLocalizations l10n) {
    final currentHome = ref.watch(currentHomeProvider);
    final allScenes = ref.watch(scenesProvider);
    final scenes = allScenes.where((s) => s.homeId == currentHome.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
                child: Text(
              l10n.quickScenes,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: palette.onSurface,
              ),
            )),
            Spacer(),
            TextButton(
              onPressed: () => setState(() => selectedTab = 2),
              child: Text(l10n.seeAll),
            ),
          ],
        ),
        SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: scenes.length,
            separatorBuilder: (_, __) => SizedBox(width: 12),
            itemBuilder: (context, index) {
              final scene = scenes[index];
              final icon = _sceneIcon(scene.iconName);

              return Semantics(
                button: true,
                label: 'Execute ${scene.name} scene',
                child: InkWell(
                  key: Key('quick_scene_${scene.id}'),
                  onTap: () => _runScene(scene),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 154,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(icon, color: palette.primary, size: 22),
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: palette.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 14,
                                color: palette.primary,
                              ),
                            ),
                          ],
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            scene.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: palette.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _sceneIcon(String name) {
    switch (name) {
      case 'wb_sunny_rounded':
        return Icons.wb_sunny_rounded;
      case 'logout_rounded':
        return Icons.logout_rounded;
      case 'bedtime_rounded':
        return Icons.bedtime_rounded;
      case 'movie_rounded':
        return Icons.movie_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Widget _buildResponsiveMetrics(
    double screenWidth,
    bool isCompact,
    AppLocalizations l10n,
  ) {
    return ListTile(
      key: Key('dashboard_energy_metric_card'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.bolt_outlined, color: palette.primary),
      title: Text(l10n.energyToday),
      trailing: Icon(Icons.arrow_forward_rounded, size: 20),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => EnergyScreen())),
    );
  }

  Widget _buildResponsiveDeviceGrid(
    List<SmartDevice> devices,
    double availableWidth,
  ) {
    final contentWidth = availableWidth -
        (availableWidth > 600 ? 64 : (availableWidth < 360 ? 28 : 44));
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final crossAxisCount = scale > 1.4 || contentWidth < 320
        ? 1
        : (contentWidth >= 800 ? 4 : (contentWidth >= 560 ? 3 : 2));
    final double spacing = 12;
    final itemWidth =
        (contentWidth - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final device in devices)
          SizedBox(
            width: itemWidth,
            child: DeviceCard(
              key: Key('device_card_${device.id}'),
              device: device,
              isBusy: pending.contains(device.id),
              onToggle: () => _send(
                device,
                DeviceCommandType.setPower,
                !device.isOn,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeviceDetailScreen(device: device),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _navigation(AppLocalizations l10n) => Container(
        padding: EdgeInsets.fromLTRB(6, 4, 6, 4),
        margin: EdgeInsets.fromLTRB(8, 0, 8, 0),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: palette.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            _tab(0, Icons.home_outlined, Icons.home_rounded, l10n.home),
            _tab(1, Icons.meeting_room_outlined, Icons.meeting_room_rounded,
                l10n.rooms),
            _tab(2, Icons.hub_outlined, Icons.hub_rounded, l10n.automation),
            _tab(3, Icons.bar_chart_outlined, Icons.bar_chart_rounded,
                l10n.activity),
            _tab(4, Icons.settings_outlined, Icons.settings_rounded,
                l10n.settings),
          ],
        ),
      );

  Widget _tab(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          key: Key('nav_tab_$index'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => selectedTab = index),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? palette.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    size: 20,
                    color:
                        isSelected ? palette.primary : palette.onSurfaceVariant,
                  ),
                  SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? palette.primary
                            : palette.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel() {
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER'
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}
