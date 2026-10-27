import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/features/backup/presentation/backup_restore_screen.dart';
import 'package:lumivo/features/privacy/presentation/privacy_center_screen.dart';
import 'package:lumivo/features/privacy/presentation/recovery_center_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 8 Privacy, Recovery & Enhanced Backup Experience Test Suite',
      () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: const [
          SmartDevice(
            id: 'device-test-1',
            name: 'Living Light',
            roomId: 'Living Room',
            type: DeviceType.light,
            isOn: true,
            brightness: 80,
            connection: DeviceConnection.online,
          ),
          SmartDevice(
            id: 'device-test-2',
            name: 'Bedroom Fan',
            roomId: 'Bedroom',
            type: DeviceType.fan,
            isOn: false,
            connection: DeviceConnection.online,
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
          homePersistenceProvider.overrideWith(
              (ref) => HomePersistenceManager(storage: StorageAdapterImpl())),
          userProfileProvider.overrideWith((ref) => UserProfileNotifier(
                UserProfile(language: locale.languageCode),
              )),
          appLocalizationsProvider.overrideWithValue(AppLocalizations(locale)),
          ...overrides,
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
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

    // =========================================================================
    // 1. Settings Navigation Entries
    // =========================================================================
    group('Settings Navigation to Privacy & Recovery Centers', () {
      testWidgets(
          'Settings screen contains settings_privacy_center_tile and navigates',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('settings_privacy_center_tile')),
            findsOneWidget);
        expect(find.text('Privacy & Data Center'), findsOneWidget);

        // Tap privacy tile
        await tester.tap(find.byKey(const Key('settings_privacy_center_tile')));
        await tester.pumpAndSettle();

        expect(find.byType(PrivacyCenterScreen), findsOneWidget);
      });

      testWidgets(
          'Settings screen contains settings_recovery_center_tile and navigates',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('settings_recovery_center_tile')),
            findsOneWidget);
        expect(find.text('Recovery Center'), findsOneWidget);

        // Tap recovery tile
        await tester
            .tap(find.byKey(const Key('settings_recovery_center_tile')));
        await tester.pumpAndSettle();

        expect(find.byType(RecoveryCenterScreen), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. Feature A — Privacy Center Screen
    // =========================================================================
    group('Feature A — Privacy Center Details & Controls', () {
      testWidgets(
          'Displays simulation mode status (100% offline, zero cloud backend)',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('privacy_simulation_mode_card')),
            findsOneWidget);
        expect(find.text('Simulation Mode Status'), findsOneWidget);
        expect(find.text('100% OFFLINE'), findsOneWidget);
        expect(
          find.text('No cloud backend · No physical hardware connection'),
          findsOneWidget,
        );
      });

      testWidgets('Displays all 9 local data storage categories breakdown',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Local Data Storage'), findsOneWidget);
        expect(find.text('Homes'), findsOneWidget);
        expect(find.text('Rooms'), findsOneWidget);
        expect(find.text('Devices'), findsOneWidget);
        expect(find.text('Automations'), findsOneWidget);
        expect(find.text('Scenes'), findsOneWidget);
        expect(find.text('Activity History'), findsOneWidget);
        expect(find.text('In-App Notifications'), findsOneWidget);
        expect(find.text('Dashboard Configs'), findsOneWidget);
        expect(find.text('Energy Telemetry'), findsOneWidget);
      });

      testWidgets(
          'Displays approximate local data usage in KB and persistence health indicator',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('privacy_persistence_health_indicator')),
            findsOneWidget);
        expect(find.text('Healthy · Optimal (Schema v6)'), findsOneWidget);
        expect(find.byKey(const Key('privacy_storage_usage_text')),
            findsOneWidget);
        expect(find.byKey(const Key('privacy_last_save_metadata')),
            findsOneWidget);
      });

      testWidgets('Quick action Export Backup triggers backup snackbar',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('privacy_export_backup_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Export Backup (JSON)'), findsWidgets);
      });

      testWidgets(
          'Quick action Open Recovery navigates to RecoveryCenterScreen',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('privacy_open_recovery_button')));
        await tester.pumpAndSettle();

        expect(find.byType(RecoveryCenterScreen), findsOneWidget);
      });

      testWidgets('Reset Demo Data requires explicit confirmation dialog',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        // Tap Reset Demo button
        await tester.tap(find.byKey(const Key('privacy_reset_demo_button')));
        await tester.pumpAndSettle();

        expect(find.text('Reset Demo Data'), findsWidgets);
        expect(
            find.byKey(const Key('confirm_reset_demo_button')), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
            find.byKey(const Key('confirm_reset_demo_button')), findsNothing);

        // Re-open and confirm
        await tester.tap(find.byKey(const Key('privacy_reset_demo_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm_reset_demo_button')));
        await tester.pumpAndSettle();

        expect(find.text('Demo environment reset to factory defaults'),
            findsOneWidget);
      });

      testWidgets(
          'Clear Activity History requires explicit confirmation dialog',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('privacy_clear_activity_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('confirm_clear_history_button')),
            findsOneWidget);

        // Confirm clear
        await tester.tap(find.byKey(const Key('confirm_clear_history_button')));
        await tester.pumpAndSettle();

        expect(find.text('Activity history cleared'), findsOneWidget);
      });

      testWidgets('Clear Notifications requires explicit confirmation dialog',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('privacy_clear_notifications_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('confirm_clear_notifications_button')),
            findsOneWidget);

        // Confirm clear
        await tester
            .tap(find.byKey(const Key('confirm_clear_notifications_button')));
        await tester.pumpAndSettle();

        expect(find.text('All notifications cleared'), findsOneWidget);
      });
    });

    // =========================================================================
    // 3. Feature C — Recovery Center Screen
    // =========================================================================
    group('Feature C — Recovery Center Operations', () {
      testWidgets('Retry loading state executes and reloads UI',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('recovery_retry_load_button')),
            findsOneWidget);
        await tester.tap(find.byKey(const Key('recovery_retry_load_button')));
        await tester.pumpAndSettle();

        expect(find.text('Home state reloaded successfully'), findsOneWidget);
      });

      testWidgets(
          'Restore snapshot is disabled when no snapshot exists and enabled after creation',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
        await tester.pumpAndSettle();

        // Initially no snapshot exists
        expect(find.text('No snapshot available'), findsWidgets);
        final restoreFinder =
            find.byKey(const Key('recovery_restore_snapshot_button'));
        expect(restoreFinder, findsOneWidget);

        // Button should be disabled (onPressed is null)
        final ElevatedButton restoreBtn = tester.widget(restoreFinder);
        expect(restoreBtn.onPressed, isNull);

        // Create a snapshot
        await tester
            .tap(find.byKey(const Key('recovery_create_snapshot_button')));
        await tester.pumpAndSettle();

        expect(find.text('Snapshot created successfully'), findsOneWidget);
        expect(find.text('Snapshot available'), findsOneWidget);

        // Now restore button is enabled and can be restored
        final ElevatedButton enabledBtn = tester
            .widget(find.byKey(const Key('recovery_restore_snapshot_button')));
        expect(enabledBtn.onPressed, isNotNull);

        await tester
            .tap(find.byKey(const Key('recovery_restore_snapshot_button')));
        await tester.pumpAndSettle();

        expect(find.text('Known-good snapshot restored successfully'),
            findsOneWidget);
      });

      testWidgets('Import backup button navigates to BackupRestoreScreen',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('recovery_import_backup_button')));
        await tester.pumpAndSettle();

        expect(find.byType(BackupRestoreScreen), findsOneWidget);
      });

      testWidgets('Factory reset requires warning modal and confirmation',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('recovery_factory_reset_button')));
        await tester.pumpAndSettle();

        expect(find.text('Confirm Factory Reset'), findsWidgets);
        expect(find.byKey(const Key('confirm_factory_reset_button')),
            findsOneWidget);

        // Confirm factory reset
        await tester.tap(find.byKey(const Key('confirm_factory_reset_button')));
        await tester.pumpAndSettle();

        expect(find.text('Demo environment reset to factory defaults'),
            findsOneWidget);
      });
    });

    // =========================================================================
    // 4. Feature B — Enhanced Backup & Restore Experience
    // =========================================================================
    group('Feature B — Enhanced Backup & Restore Experience', () {
      testWidgets(
          'Valid backup preview presents entity counts, supported schema, and no secrets',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_backup_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('backup_preview_dialog')), findsOneWidget);
        expect(find.byKey(const Key('backup_preview_validation_status')),
            findsOneWidget);
        expect(
            find.byKey(const Key('backup_preview_home_count')), findsOneWidget);
        expect(
            find.byKey(const Key('backup_preview_room_count')), findsOneWidget);
        expect(find.byKey(const Key('backup_preview_device_count')),
            findsOneWidget);
        expect(find.byKey(const Key('backup_preview_scene_count')),
            findsOneWidget);
        expect(find.byKey(const Key('backup_preview_automation_count')),
            findsOneWidget);

        // Verify zero secrets notice
        expect(find.text('Credentials & Secrets: None (Sanitized)'),
            findsOneWidget);
        // Verify replace data warning
        expect(
          find.descendant(
            of: find.byKey(const Key('backup_preview_dialog')),
            matching: find.text(
                'This will replace existing smart home data with the backup payload.'),
          ),
          findsOneWidget,
        );

        // Confirm restore
        await tester
            .tap(find.byKey(const Key('confirm_restore_backup_button')));
        await tester.pumpAndSettle();

        expect(find.text('Home state restored successfully'), findsOneWidget);
      });

      testWidgets('Actionable failure message for malformed JSON payload',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        // Select preset malformed JSON
        await tester.tap(find.byKey(const Key('preset_malformed_json_chip')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_backup_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('backup_error_banner')), findsOneWidget);
        expect(find.textContaining('Malformed JSON payload'), findsWidgets);
      });

      testWidgets('Actionable failure message for oversized payload (>5MB)',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        // Select preset oversized payload
        await tester.tap(find.byKey(const Key('preset_oversized_chip')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_backup_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('backup_error_banner')), findsOneWidget);
        expect(
            find.textContaining('Payload exceeds maximum allowed size (5MB).'),
            findsWidgets);
      });

      testWidgets('Actionable failure message for unsupported schema version',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        // Select preset unsupported schema (v7)
        await tester
            .tap(find.byKey(const Key('preset_unsupported_schema_chip')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_backup_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('backup_error_banner')), findsOneWidget);
        expect(
            find.textContaining('Unsupported schema version: 7'), findsWidgets);
      });

      testWidgets('Actionable failure message for duplicate device IDs',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        // Select preset duplicate ID
        await tester.tap(find.byKey(const Key('preset_duplicate_id_chip')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('import_backup_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('backup_error_banner')), findsOneWidget);
        expect(find.textContaining('Duplicate device ID found: device-dup'),
            findsWidgets);
      });
    });

    // =========================================================================
    // 5. Accessibility Semantics & Touch Targets (>= 48x48 pt)
    // =========================================================================
    group('Accessibility Semantics & Touch Target Compliance', () {
      testWidgets(
          'Privacy Center quick action buttons meet >= 48pt touch targets',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        final buttonKeys = [
          'privacy_export_backup_button',
          'privacy_open_recovery_button',
          'privacy_clear_activity_button',
          'privacy_clear_notifications_button',
          'privacy_reset_demo_button',
        ];

        for (final key in buttonKeys) {
          final size = tester.getSize(find.byKey(Key(key)));
          expect(
            size.height,
            greaterThanOrEqualTo(48.0),
            reason: 'Button $key height must be >= 48pt',
          );
          expect(
            size.width,
            greaterThanOrEqualTo(48.0),
            reason: 'Button $key width must be >= 48pt',
          );
        }
      });

      testWidgets('Recovery Center action buttons meet >= 48pt touch targets',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
        await tester.pumpAndSettle();

        final buttonKeys = [
          'recovery_retry_load_button',
          'recovery_restore_snapshot_button',
          'recovery_create_snapshot_button',
          'recovery_import_backup_button',
          'recovery_factory_reset_button',
        ];

        for (final key in buttonKeys) {
          final size = tester.getSize(find.byKey(Key(key)));
          expect(
            size.height,
            greaterThanOrEqualTo(48.0),
            reason: 'Button $key height must be >= 48pt',
          );
          expect(
            size.width,
            greaterThanOrEqualTo(48.0),
            reason: 'Button $key width must be >= 48pt',
          );
        }
      });
    });

    // =========================================================================
    // 6. Bilingual Localization (EN & VI)
    // =========================================================================
    group('Bilingual Localization Switching (EN & VI)', () {
      testWidgets('Privacy Center translates accurately to Vietnamese',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const PrivacyCenterScreen(),
          locale: const Locale('vi'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Trung tâm Quyền riêng tư & Dữ liệu'), findsOneWidget);
        expect(find.text('Trạng thái Chế độ Mô phỏng'), findsOneWidget);
        expect(find.text('Lưu trữ Dữ liệu Cục bộ'), findsOneWidget);
        expect(find.text('Phân loại Dữ liệu Lưu trữ'), findsOneWidget);
      });

      testWidgets('Recovery Center translates accurately to Vietnamese',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const RecoveryCenterScreen(),
          locale: const Locale('vi'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Trung tâm Phục hồi'), findsWidgets);
        expect(find.text('Tải lại Trạng thái'), findsWidgets);
        expect(find.text('Nhập Tệp Sao lưu'), findsWidgets);
        expect(find.text('Khôi phục Cài đặt Gốc Demo'), findsWidgets);
      });
    });

    // =========================================================================
    // 7. Narrow Viewport Responsiveness (320x600)
    // =========================================================================
    group('Narrow Viewport Responsiveness (320x600)', () {
      testWidgets('PrivacyCenterScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('privacy_simulation_mode_card')),
            findsOneWidget);
      });

      testWidgets('RecoveryCenterScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('recovery_retry_load_button')),
            findsOneWidget);
      });

      testWidgets('BackupRestoreScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('export_backup_button')), findsOneWidget);
      });
    });
  });
}
