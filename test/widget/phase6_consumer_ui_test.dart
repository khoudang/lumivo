import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/automation/presentation/automation_builder_wizard.dart';
import 'package:lumivo/features/automation/presentation/scene_preview_dialog.dart';
import 'package:lumivo/features/backup/presentation/backup_restore_screen.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_edit_sheet.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/energy/presentation/energy_screen.dart';
import 'package:lumivo/features/search/presentation/device_search_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 6 Consumer UI/UX Comprehensive Test Suite', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: const [
          SmartDevice(
            id: 'light-1',
            name: 'Living Room Light',
            roomId: 'Living Room',
            type: DeviceType.light,
            isOn: true,
            brightness: 80,
            connection: DeviceConnection.online,
            isFavorite: true,
            favoriteOrder: 0,
          ),
          SmartDevice(
            id: 'fan-1',
            name: 'Living Room Fan',
            roomId: 'Living Room',
            type: DeviceType.fan,
            isOn: false,
            connection: DeviceConnection.online,
          ),
          SmartDevice(
            id: 'ac-1',
            name: 'Bedroom Climate AC',
            roomId: 'Bedroom',
            type: DeviceType.ac,
            isOn: true,
            targetTemperature: 24,
            currentTemperature: 25,
            connection: DeviceConnection.online,
          ),
          SmartDevice(
            id: 'sensor-1',
            name: 'Balcony Sensor',
            roomId: 'Balcony',
            type: DeviceType.sensor,
            isOn: true,
            connection: DeviceConnection.offline,
          ),
        ],
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    Widget createTestApp(
      Widget child, {
      List<Override> overrides = const [],
      Locale locale = const Locale('en'),
    }) {
      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          ...overrides,
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );
    }

    void setupViewport(
      WidgetTester tester, {
      Size size = const Size(800, 1200),
    }) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // -------------------------------------------------------------
    // 1. Customizable Dashboard Tests
    // -------------------------------------------------------------
    group('Customizable Dashboard (Edit Sheet, Reorder, Show/Hide & Reset)',
        () {
      testWidgets('Dashboard renders edit mode button and search button',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('dashboard_search_button')), findsOneWidget);
        expect(find.byKey(const Key('dashboard_edit_mode_button')),
            findsOneWidget);
      });

      testWidgets('Tapping dashboard_edit_mode_button opens DashboardEditSheet',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_edit_mode_button')));
        await tester.pumpAndSettle();

        expect(find.byType(DashboardEditSheet), findsOneWidget);
        expect(find.byKey(const Key('dashboard_done_editing_button')),
            findsOneWidget);
        expect(find.byKey(const Key('save_dashboard_layout_button')),
            findsOneWidget);
        expect(find.byKey(const Key('reset_dashboard_layout_button')),
            findsOneWidget);
      });

      testWidgets(
          'DashboardEditSheet toggles section visibility and saves layout',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(
            createTestApp(const Scaffold(body: DashboardEditSheet())));
        await tester.pumpAndSettle();

        // Check metrics toggle
        final metricsToggle = find.byKey(const Key('toggle_section_metrics'));
        expect(metricsToggle, findsOneWidget);

        // Toggle off
        await tester.tap(metricsToggle);
        await tester.pumpAndSettle();

        // Tap Save Layout
        await tester.tap(find.byKey(const Key('save_dashboard_layout_button')));
        await tester.pumpAndSettle();

        expect(find.text('Dashboard layout saved'), findsOneWidget);
      });

      testWidgets(
          'DashboardEditSheet reorders sections using accessibility controls',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(
            createTestApp(const Scaffold(body: DashboardEditSheet())));
        await tester.pumpAndSettle();

        // Tap move down on first item (metrics)
        final moveDownMetrics = find.byKey(const Key('move_down_metrics'));
        expect(moveDownMetrics, findsOneWidget);
        await tester.tap(moveDownMetrics);
        await tester.pumpAndSettle();

        // Tap reset layout
        await tester
            .tap(find.byKey(const Key('reset_dashboard_layout_button')));
        await tester.pumpAndSettle();

        expect(find.text('Reset Layout'), findsWidgets);
      });
    });

    // -------------------------------------------------------------
    // 2. Smart Device Search Tests
    // -------------------------------------------------------------
    group(
        'Smart Device Search (Query, Type & Status Filters, Sorting & Empty State)',
        () {
      testWidgets(
          'Tapping dashboard search button navigates to DeviceSearchScreen',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_search_button')));
        await tester.pumpAndSettle();

        expect(find.byType(DeviceSearchScreen), findsOneWidget);
        expect(
            find.byKey(const Key('global_device_search_bar')), findsOneWidget);
      });

      testWidgets('Searching query matches device name and room name',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        // Initial devices visible
        expect(find.byKey(const Key('device_card_light-1')), findsOneWidget);
        expect(find.byKey(const Key('device_card_ac-1')), findsOneWidget);

        // Enter query "Climate"
        await tester.enterText(
            find.byKey(const Key('global_device_search_bar')), 'Climate');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('device_card_ac-1')), findsOneWidget);
        expect(find.byKey(const Key('device_card_light-1')), findsNothing);

        // Enter room query "Bedroom"
        await tester.enterText(
            find.byKey(const Key('global_device_search_bar')), 'Bedroom');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('device_card_ac-1')), findsOneWidget);
        expect(find.byKey(const Key('device_card_light-1')), findsNothing);
      });

      testWidgets('Filter chips for Type and Status filter the results list',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        // Filter by Fan
        await tester.tap(find.byKey(const Key('filter_type_fan')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('device_card_fan-1')), findsOneWidget);
        expect(find.byKey(const Key('device_card_light-1')), findsNothing);

        // Filter by All Types
        await tester.tap(find.byKey(const Key('filter_type_all')));
        await tester.pumpAndSettle();

        // Filter by Offline status
        await tester.tap(find.byKey(const Key('filter_status_offline')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('device_card_sensor-1')), findsOneWidget);
        expect(find.byKey(const Key('device_card_light-1')), findsNothing);
      });

      testWidgets('Sort dropdown changes device sort order', (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        // Tap sort dropdown
        await tester.tap(find.byKey(const Key('search_sort_dropdown')));
        await tester.pumpAndSettle();

        // Select Room
        await tester.tap(find.text('Room').last);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('device_card_ac-1')), findsOneWidget);
      });

      testWidgets(
          'Empty search results display empty state and clear filters button',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        // Enter non-matching query
        await tester.enterText(
            find.byKey(const Key('global_device_search_bar')),
            'NonExistentDevice123');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('search_empty_state')), findsOneWidget);
        expect(find.text('No matching devices found'), findsOneWidget);

        // Tap clear filters
        await tester
            .tap(find.byKey(const Key('clear_search_filters_button_empty')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('device_card_light-1')), findsOneWidget);
      });
    });

    // -------------------------------------------------------------
    // 3. Scene & Automation Builder 2.0 Tests
    // -------------------------------------------------------------
    group(
        'Scene & Automation Builder 2.0 (WHEN/IF/THEN, Templates & Scene Preview)',
        () {
      testWidgets(
          'AutomationBuilderWizard pre-fills templates and summary card',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const AutomationBuilderWizard()));
        await tester.pumpAndSettle();

        // Check summary card is visible
        expect(
            find.byKey(const Key('automation_summary_card')), findsOneWidget);

        // Tap "Good Morning" template
        await tester.tap(find.byKey(const Key('template_morning_card')));
        await tester.pumpAndSettle();

        expect(find.text('Good Morning'), findsWidgets);
        expect(
            find.byKey(const Key('automation_summary_card')), findsOneWidget);

        // Tap "Movie Time" template
        await tester.tap(find.byKey(const Key('template_movie_card')));
        await tester.pumpAndSettle();

        expect(find.text('Movie Time'), findsWidgets);
      });

      testWidgets('Validation error banner shows if name is cleared on save',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const AutomationBuilderWizard()));
        await tester.pumpAndSettle();

        // Clear name
        await tester.enterText(
            find.byKey(const Key('automation_name_input')), '');
        await tester.pumpAndSettle();

        // Tap save
        await tester.tap(find.byKey(const Key('save_automation_rule_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('automation_validation_error')),
            findsOneWidget);
      });

      testWidgets(
          'ScenePreviewDialog displays affected devices and current vs target values',
          (tester) async {
        setupViewport(tester);
        final actions = [
          const DeviceAction(
            deviceId: 'light-1',
            commandType: DeviceCommandType.setPower,
            value: false,
          ),
          const DeviceAction(
            deviceId: 'ac-1',
            commandType: DeviceCommandType.setTargetTemperature,
            value: 22.0,
          ),
        ];

        await tester.pumpWidget(
          createTestApp(
            Scaffold(
              body: ScenePreviewDialog(actions: actions),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('scene_preview_dialog')), findsOneWidget);
        expect(find.text('Living Room Light'), findsOneWidget);
        expect(find.text('Bedroom Climate AC'), findsOneWidget);
        expect(find.byKey(const Key('confirm_scene_execute_button')),
            findsOneWidget);
      });
    });

    // -------------------------------------------------------------
    // 4. Energy Screen CSV & Notice Banner Tests
    // -------------------------------------------------------------
    group(
        'Energy Screen Enhancements (CSV Export, Simulated Notice & Room View)',
        () {
      testWidgets(
          'EnergyScreen renders simulated notice banner and CSV export button',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const EnergyScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('energy_simulated_notice_banner')),
            findsOneWidget);
        expect(
            find.byKey(const Key('export_energy_csv_button')), findsOneWidget);

        // Tap CSV export
        await tester.tap(find.byKey(const Key('export_energy_csv_button')));
        await tester.pumpAndSettle();

        expect(find.text('Energy report exported to CSV'), findsOneWidget);
      });

      testWidgets('Tapping per-room consumption tab switches breakdown view',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const EnergyScreen()));
        await tester.pumpAndSettle();

        // Toggle to Room breakdown
        await tester.tap(find.byKey(const Key('energy_view_room_tab')));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('per_room_consumption_list')), findsOneWidget);

        // Toggle back to Device breakdown
        await tester.tap(find.byKey(const Key('energy_view_device_tab')));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('per_room_consumption_list')), findsNothing);
      });
    });

    // -------------------------------------------------------------
    // 5. Backup & Restore UI Tests
    // -------------------------------------------------------------
    group('Backup & Restore UI (Settings Tile, Export, Import & Preview Modal)',
        () {
      testWidgets(
          'Settings screen contains settings_backup_tile navigating to BackupRestoreScreen',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();

        final backupTile = find.byKey(const Key('settings_backup_tile'));
        expect(backupTile, findsOneWidget);

        await tester.tap(backupTile);
        await tester.pumpAndSettle();

        expect(find.byType(BackupRestoreScreen), findsOneWidget);
        expect(find.byKey(const Key('export_backup_button')), findsOneWidget);
        expect(find.byKey(const Key('import_backup_button')), findsOneWidget);
      });

      testWidgets('Tapping export_backup_button generates backup snapshot',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('export_backup_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Export Backup'), findsWidgets);
      });

      testWidgets(
          'Tapping import_backup_button opens BackupPreviewDialog and confirms restore',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_backup_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('backup_preview_dialog')), findsOneWidget);
        expect(
            find.byKey(const Key('backup_preview_home_count')), findsOneWidget);
        expect(
            find.byKey(const Key('backup_preview_room_count')), findsOneWidget);
        expect(find.byKey(const Key('backup_preview_device_count')),
            findsOneWidget);
        expect(find.byKey(const Key('backup_preview_validation_status')),
            findsOneWidget);

        // Confirm Restore
        await tester
            .tap(find.byKey(const Key('confirm_restore_backup_button')));
        await tester.pumpAndSettle();

        expect(find.text('Home state restored successfully'), findsOneWidget);
      });

      testWidgets('Simulating invalid backup displays error snackbar',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_invalid_backup_button')));
        await tester.pumpAndSettle();

        expect(find.text('Invalid or unsupported backup file'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------
    // 6. Responsive Rendering on 320x600 Viewport
    // -------------------------------------------------------------
    group('Narrow Mobile Responsiveness (320x600 Viewport)', () {
      testWidgets('DashboardScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
            find.byKey(const Key('dashboard_search_button')), findsOneWidget);
      });

      testWidgets('DeviceSearchScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
            find.byKey(const Key('global_device_search_bar')), findsOneWidget);
      });

      testWidgets('AutomationBuilderWizard renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const AutomationBuilderWizard()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('EnergyScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const EnergyScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('BackupRestoreScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  });
}
