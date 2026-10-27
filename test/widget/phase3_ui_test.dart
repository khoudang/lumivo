import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/automation/presentation/scene_editor_sheet.dart';
import 'package:lumivo/features/dashboard/widgets/favorites_section.dart';
import 'package:lumivo/features/device_detail/presentation/device_settings_sheet.dart';
import 'package:lumivo/features/energy/presentation/energy_screen.dart';
import 'package:lumivo/features/home/presentation/home_app_bar_title.dart';
import 'package:lumivo/features/home/presentation/home_selector_sheet.dart';
import 'package:lumivo/features/profile/presentation/profile_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 3 UI Comprehensive Test Suite', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
    });

    tearDown(() async {
      await repository.dispose();
    });

    void setupViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Widget createTestApp(Widget child, {List<Override> overrides = const []}) {
      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          ...overrides,
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('HomeSelectorSheet renders and allows selecting a home',
        (WidgetTester tester) async {
      setupViewport(tester);

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_sheet_btn'),
                  onPressed: () => HomeSelectorSheet.show(context),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open HomeSelectorSheet
      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // 1. Verify sheet header & active home banner
      expect(find.text('Switch Home'), findsOneWidget);
      expect(find.byKey(const Key('active_home_banner')), findsOneWidget);
      expect(find.text('Downtown Penthouse'), findsWidgets);
      expect(find.text('Owner'), findsWidgets);

      // 2. Verify available homes list items
      expect(find.text('Suburban Villa'), findsOneWidget);

      // 3. Switch active home to Lake Tahoe Cabin
      await tester.tap(find.text('Suburban Villa'));
      await tester.pumpAndSettle();

      // Verify active home indicator updated
      final banner = find.byKey(const Key('active_home_banner'));
      expect(
        find.descendant(of: banner, matching: find.text('Suburban Villa')),
        findsOneWidget,
      );

      // 4. Test Add New Home dialog
      expect(find.byKey(const Key('add_new_home_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add_new_home_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add New Home'), findsOneWidget);
      expect(find.byKey(const Key('add_home_name_input')), findsOneWidget);
      expect(find.byKey(const Key('add_home_address_input')), findsOneWidget);
      expect(find.byKey(const Key('add_home_tariff_input')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('add_home_name_input')), 'Aspen Ski Chalet');
      await tester.enterText(
          find.byKey(const Key('add_home_address_input')), '700 Snowmass Rd');
      await tester.enterText(
          find.byKey(const Key('add_home_tariff_input')), '0.195');

      await tester.tap(find.byKey(const Key('confirm_add_home_button')));
      await tester.pumpAndSettle();

      // Verify new home added to available homes
      expect(find.text('Aspen Ski Chalet'), findsOneWidget);
    });

    testWidgets('HomeAppBarTitle renders and triggers home selector',
        (WidgetTester tester) async {
      setupViewport(tester);

      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: SafeArea(
                child: Row(
                  children: [
                    HomeAppBarTitle(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('home_app_bar_title_button')), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.text('Downtown Penthouse'), findsOneWidget);

      // Tap HomeAppBarTitle opens HomeSelectorSheet
      await tester.tap(find.byKey(const Key('home_app_bar_title_button')));
      await tester.pumpAndSettle();

      expect(find.text('Switch Home'), findsOneWidget);
    });

    testWidgets(
        'DeviceSettingsSheet renders fields (rename, favorite toggle, delete confirmation)',
        (WidgetTester tester) async {
      setupViewport(tester);

      const testDevice = SmartDevice(
        id: 'light-1',
        name: 'Smart Light',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: true,
        isFavorite: false,
      );

      SmartDevice? savedDevice;
      String? deletedDeviceId;

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_settings_btn'),
                  onPressed: () => DeviceSettingsSheet.show(
                    context,
                    testDevice,
                    onSave: (dev) => savedDevice = dev,
                    onDelete: (id) => deletedDeviceId = id,
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_settings_btn')));
      await tester.pumpAndSettle();

      // 1. Verify fields render
      expect(find.text('Device Settings'), findsOneWidget);
      expect(
          find.byKey(const Key('device_settings_name_input')), findsOneWidget);
      expect(find.byKey(const Key('device_settings_favorite_switch')),
          findsOneWidget);
      expect(find.byKey(const Key('device_settings_room_dropdown')),
          findsOneWidget);
      expect(find.byKey(const Key('custom_icon_bulb')), findsOneWidget);
      expect(find.byKey(const Key('custom_icon_desk_lamp')), findsOneWidget);
      expect(find.byKey(const Key('custom_icon_fan')), findsOneWidget);
      expect(find.byKey(const Key('device_settings_delete_button')),
          findsOneWidget);
      expect(
          find.byKey(const Key('device_settings_save_button')), findsOneWidget);

      // 2. Test renaming device & custom icon & toggling favorite
      await tester.enterText(
          find.byKey(const Key('device_settings_name_input')),
          'Ambient Arc Light');
      await tester.tap(find.byKey(const Key('custom_icon_desk_lamp')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('device_settings_favorite_switch')));
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.byKey(const Key('device_settings_save_button')));
      await tester.pumpAndSettle();

      expect(savedDevice, isNotNull);
      expect(savedDevice!.name, 'Ambient Arc Light');
      expect(savedDevice!.customIcon, 'desk_lamp');
      expect(savedDevice!.isFavorite, isTrue);

      // 3. Test Delete confirmation dialog
      await tester.tap(find.byKey(const Key('open_settings_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('device_settings_delete_button')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Device?'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_device_button')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_delete_device_button')));
      await tester.pumpAndSettle();

      expect(deletedDeviceId, 'light-1');
    });

    testWidgets(
        'FavoritesSection renders empty state, cards, and supports reordering',
        (WidgetTester tester) async {
      setupViewport(tester);

      int? reorderedOld;
      int? reorderedNew;

      // 1. Empty state
      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: FavoritesSection(
              favoriteDevices: const [],
              onReorder: (oldIdx, newIdx) {
                reorderedOld = oldIdx;
                reorderedNew = newIdx;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('favorites_empty_state')), findsOneWidget);
      expect(
        find.text(
            'No favorite devices pinned yet. Long press or tap settings on any device to add to favorites.'),
        findsOneWidget,
      );

      // 2. Populated favorites list
      const fav1 = SmartDevice(
        id: 'light-1',
        name: 'Desk Light',
        roomId: 'Office',
        type: DeviceType.light,
        isOn: true,
        isFavorite: true,
      );
      const fav2 = SmartDevice(
        id: 'ac-1',
        name: 'Main AC',
        roomId: 'Living Room',
        type: DeviceType.ac,
        isOn: false,
        isFavorite: true,
      );

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: FavoritesSection(
              favoriteDevices: const [fav1, fav2],
              onReorder: (oldIdx, newIdx) {
                reorderedOld = oldIdx;
                reorderedNew = newIdx;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.byKey(const Key('favorites_count_badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byKey(const Key('favorite_card_light-1')), findsOneWidget);
      expect(find.byKey(const Key('favorite_card_ac-1')), findsOneWidget);
      expect(find.byKey(const Key('favorite_badge_light-1')), findsOneWidget);
      expect(find.text('Desk Light'), findsOneWidget);
      expect(find.text('Main AC'), findsOneWidget);

      // Verify onReorder callback invocation
      final reorderList =
          tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      // ignore: deprecated_member_use
      reorderList.onReorder!(0, 2);
      expect(reorderedOld, 0);
      expect(reorderedNew, 2);
    });

    testWidgets(
        'EnergyScreen renders metrics, period selector and simulated disclaimer badge',
        (WidgetTester tester) async {
      setupViewport(tester);

      await tester.pumpWidget(
        createTestApp(
          const EnergyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify header & disclaimer badge
      expect(find.text('Energy Analytics'), findsOneWidget);
      expect(find.byKey(const Key('energy_simulation_badge')), findsOneWidget);
      expect(
          find.text('SIMULATED TELEMETRY • VIRTUAL ESTIMATE'), findsOneWidget);

      // 2. Verify tariff note
      expect(find.byKey(const Key('energy_tariff_note')), findsOneWidget);
      expect(find.textContaining('/ kWh (Simulated)'), findsOneWidget);

      // 3. Verify key metrics cards
      expect(find.byKey(const Key('metric_total_kwh')), findsOneWidget);
      expect(find.byKey(const Key('metric_estimated_cost')), findsOneWidget);
      expect(find.byKey(const Key('metric_average_watts')), findsOneWidget);
      expect(find.byKey(const Key('metric_peak_watts')), findsOneWidget);

      // Day metrics values
      expect(find.text('14.8 kWh'), findsOneWidget);

      // 4. Period selector tabs
      expect(find.byKey(const Key('period_tab_day')), findsOneWidget);
      expect(find.byKey(const Key('period_tab_week')), findsOneWidget);
      expect(find.byKey(const Key('period_tab_month')), findsOneWidget);

      // Switch to Week period
      await tester.tap(find.byKey(const Key('period_tab_week')));
      await tester.pumpAndSettle();

      expect(find.text('98.4 kWh'), findsOneWidget);

      // Switch to Month period
      await tester.tap(find.byKey(const Key('period_tab_month')));
      await tester.pumpAndSettle();

      expect(find.text('412.0 kWh'), findsOneWidget);

      // 5. Verify History chart and device breakdown
      expect(find.byKey(const Key('energy_history_chart')), findsOneWidget);
      expect(find.text('Device Energy Breakdown'), findsOneWidget);

      // 6. Test Edit Tariff Dialog
      expect(find.byKey(const Key('edit_tariff_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit_tariff_button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Tariff Rate'), findsOneWidget);
      expect(find.byKey(const Key('edit_tariff_rate_input')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('edit_tariff_rate_input')), '0.185');
      await tester.tap(find.byKey(const Key('confirm_tariff_rate_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('0.185'), findsWidgets);
    });

    testWidgets(
        'ProfileScreen renders preferences (language, reduced motion, temperature unit)',
        (WidgetTester tester) async {
      setupViewport(tester);

      await tester.pumpWidget(
        createTestApp(
          const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. User Profile Card
      expect(find.byKey(const Key('user_profile_card')), findsOneWidget);
      expect(find.text('Alex Mercer'), findsOneWidget);
      expect(find.text('alex.mercer@lumivo.io'), findsOneWidget);
      expect(find.text('Home Administrator'), findsOneWidget);

      // 2. Preferences
      expect(find.byKey(const Key('preference_language_selector')),
          findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);

      expect(find.byKey(const Key('preference_theme_toggle')), findsOneWidget);
      expect(find.text('Dark Minimal'), findsOneWidget);
      expect(find.text('OLED Black'), findsOneWidget);

      expect(find.byKey(const Key('preference_reduced_motion_switch')),
          findsOneWidget);
      expect(find.text('Reduced Motion'), findsOneWidget);

      expect(find.byKey(const Key('preference_temp_unit_selector')),
          findsOneWidget);
      expect(find.text('Celsius (°C)'), findsOneWidget);
      expect(find.text('Fahrenheit (°F)'), findsOneWidget);

      expect(find.byKey(const Key('preference_tariff_tile')), findsOneWidget);

      // 3. Interact with preferences
      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OLED Black'));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('preference_reduced_motion_switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fahrenheit (°F)'));
      await tester.pumpAndSettle();

      // 4. Disclaimer
      expect(find.byKey(const Key('profile_simulation_disclaimer')),
          findsOneWidget);
      expect(find.textContaining('Simulation'), findsWidgets);

      // 5. Electricity Tariff setting dialog from Profile
      await tester.tap(find.byKey(const Key('preference_tariff_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Electricity Tariff Setting'), findsOneWidget);
      expect(find.byKey(const Key('profile_tariff_input')), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('profile_tariff_input')), '0.175');
      await tester.tap(find.byKey(const Key('confirm_profile_tariff_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('0.175'), findsWidgets);
    });

    testWidgets('SceneEditorSheet renders name input and action selector',
        (WidgetTester tester) async {
      setupViewport(tester);

      Scene? savedScene;
      String? deletedSceneId;

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_scene_editor_btn'),
                  onPressed: () => SceneEditorSheet.show(
                    context,
                    onSave: (sc) => savedScene = sc,
                    onDelete: (id) => deletedSceneId = id,
                  ),
                  child: const Text('Open Scene Editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_scene_editor_btn')));
      await tester.pumpAndSettle();

      // 1. Verify editor header, name input & icon picker
      expect(find.text('Create New Scene'), findsOneWidget);
      expect(find.byKey(const Key('scene_editor_name_input')), findsOneWidget);
      expect(find.byKey(const Key('scene_icon_auto_awesome')), findsOneWidget);
      expect(find.byKey(const Key('scene_icon_movie_rounded')), findsOneWidget);
      expect(
          find.byKey(const Key('scene_icon_wb_sunny_rounded')), findsOneWidget);

      // 2. Add an action
      expect(find.byKey(const Key('scene_editor_add_action_button')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('scene_editor_add_action_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add Scene Action'), findsOneWidget);
      expect(find.byKey(const Key('action_select_device_dropdown')),
          findsOneWidget);
      expect(
          find.byKey(const Key('confirm_add_action_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_add_action_button')));
      await tester.pumpAndSettle();

      // Action row should now be present
      expect(find.byKey(const Key('scene_action_item_0')), findsOneWidget);

      // 3. Enter name, pick icon and save scene
      await tester.enterText(
          find.byKey(const Key('scene_editor_name_input')), 'Sunset Chill');
      await tester.tap(find.byKey(const Key('scene_icon_movie_rounded')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('scene_editor_save_button')));
      await tester.pumpAndSettle();

      expect(savedScene, isNotNull);
      expect(savedScene!.name, 'Sunset Chill');
      expect(savedScene!.iconName, 'movie_rounded');
      expect(savedScene!.actions.length, 1);

      // 4. Test Edit mode with initialScene & Delete button
      const existingScene = Scene(
        id: 'scene-test-delete',
        name: 'Party Time',
        iconName: 'auto_awesome',
        actions: [
          DeviceAction(
            deviceId: 'light-1',
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_scene_edit_existing_btn'),
                  onPressed: () => SceneEditorSheet.show(
                    context,
                    scene: existingScene,
                    onSave: (sc) => savedScene = sc,
                    onDelete: (id) => deletedSceneId = id,
                  ),
                  child: const Text('Open Edit Scene'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_scene_edit_existing_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Scene'), findsOneWidget);
      expect(find.text('Party Time'), findsOneWidget);
      expect(
          find.byKey(const Key('scene_editor_delete_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('scene_editor_delete_button')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Scene?'), findsOneWidget);
      expect(
          find.byKey(const Key('confirm_delete_scene_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_delete_scene_button')));
      await tester.pumpAndSettle();

      expect(deletedSceneId, 'scene-test-delete');
    });
  });
}
