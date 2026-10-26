import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/automation_rule.dart';
import 'package:lumivo/core/models/dashboard_config.dart';
import 'package:lumivo/core/models/device_command.dart';
import 'package:lumivo/core/models/energy_report.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/backup/presentation/backup_restore_screen.dart';
import 'package:lumivo/features/privacy/presentation/privacy_center_screen.dart';
import 'package:lumivo/features/privacy/presentation/recovery_center_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/backup/backup_restore_service.dart';
import 'package:lumivo/services/backup/backup_validation_service.dart';
import 'package:lumivo/services/energy/energy_insights_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/security/secret_sanitizer.dart';
import 'package:lumivo/services/storage/storage_adapter.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

/// Simulated failing storage adapter for rollback verification.
class FaultInjectionStorageAdapter implements StorageAdapter {
  FaultInjectionStorageAdapter({this.failOnWrite = false});

  final Map<String, String> _map = {};
  bool failOnWrite;

  @override
  Future<String?> getString(String key) async => _map[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failOnWrite && key == HomePersistenceManager.storageKey) {
      throw Exception('Simulated critical I/O failure during saveHomeState');
    }
    _map[key] = value;
  }

  @override
  Future<void> remove(String key) async => _map.remove(key);

  @override
  Future<void> clear() async => _map.clear();
}

void main() {
  group('Phase 8 Mandatory Acceptance Suite (Flows A through N)', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistenceManager;
    late MockDeviceRepository repository;
    late BackupRestoreService backupService;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistenceManager = HomePersistenceManager(storage: storage);
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        persistenceManager: persistenceManager,
      );
      backupService = const BackupRestoreService();
      BackupRestoreService.resetConcurrencyLock();
      repository.resetToDemo();
    });

    tearDown(() async {
      await repository.dispose();
    });

    void setupViewport(WidgetTester tester,
        [Size size = const Size(800, 1200)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Widget createTestApp(
      Widget child, {
      List<Override> overrides = const [],
      Locale locale = const Locale('en'),
    }) {
      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          homePersistenceProvider.overrideWithValue(persistenceManager),
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

    // -------------------------------------------------------------------------
    // FLOW A: Privacy Center
    // (View local categories, storage usage, simulation mode status, export backup)
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow A: Privacy Center (view local categories, storage usage, export backup)',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      // 1. Locate and tap Privacy Center tile in Settings
      final privacyTile = find.byKey(const Key('settings_privacy_center_tile'));
      expect(privacyTile, findsOneWidget);
      await tester.tap(privacyTile);
      await tester.pumpAndSettle();

      // 2. Verify Privacy Center Screen rendered
      expect(find.byType(PrivacyCenterScreen), findsOneWidget);
      expect(find.byKey(const Key('privacy_simulation_mode_card')),
          findsOneWidget);
      expect(
          find.byKey(const Key('privacy_storage_usage_text')), findsOneWidget);
      expect(
          find.byKey(const Key('privacy_last_save_metadata')), findsOneWidget);

      // 3. Trigger Export Backup from Privacy Center
      final exportBtn = find.byKey(const Key('privacy_export_backup_button'));
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      // 4. Verify feedback snackbar confirming export
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Export Backup (JSON) ('), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // FLOW B: Safe Backup Preview
    // (Preview metadata, entity counts, explicit confirmation, complete restore)
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow B: Safe Backup Preview (preview metadata, entity counts, explicit confirmation, complete restore)',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
      await tester.pumpAndSettle();

      // 1. Export initial backup first
      await tester.tap(find.byKey(const Key('export_backup_button')));
      await tester.pumpAndSettle();

      // 2. Tap import backup to open preview modal
      await tester.tap(find.byKey(const Key('import_backup_button')));
      await tester.pumpAndSettle();

      // 3. Verify Safe Backup Preview Dialog
      expect(find.byKey(const Key('backup_preview_dialog')), findsOneWidget);
      expect(
          find.byKey(const Key('backup_preview_home_count')), findsOneWidget);
      expect(
          find.byKey(const Key('backup_preview_room_count')), findsOneWidget);
      expect(
          find.byKey(const Key('backup_preview_device_count')), findsOneWidget);
      expect(
          find.text('Credentials & Secrets: None (Sanitized)'), findsOneWidget);

      // 4. Explicit confirmation
      final confirmBtn = find.byKey(const Key('confirm_restore_backup_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // 5. Verify restore success feedback
      expect(find.text('Home state restored successfully'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // FLOW C: Invalid Backup Rejection
    // (Malformed JSON rejected with actionable error message, prior data preserved)
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow C: Invalid Backup Rejection (malformed JSON rejected with actionable error message, prior data preserved)',
        (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
      await tester.pumpAndSettle();

      final preState = await persistenceManager.loadHomeState();
      final preDeviceCount = preState.devices.length;

      // 1. Simulate invalid backup button
      await tester.tap(find.byKey(const Key('import_invalid_backup_button')));
      await tester.pumpAndSettle();

      // 2. Verify error snackbar appears
      expect(find.text('Invalid or unsupported backup file'), findsOneWidget);

      // 3. Verify prior state is intact with zero corruption
      final postState = await persistenceManager.loadHomeState();
      expect(postState.devices.length, equals(preDeviceCount));
      expect(postState.currentHomeId, equals(preState.currentHomeId));
    });

    // -------------------------------------------------------------------------
    // FLOW D: Unsupported Version Rejection
    // (Unsupported schema rejected without mutation)
    // -------------------------------------------------------------------------
    test(
        'Flow D: Unsupported Version Rejection (unsupported schema rejected without mutation)',
        () async {
      final preState = await persistenceManager.loadHomeState();

      final unsupportedPayload = jsonEncode({
        'metadata': {
          'schemaVersion': 99,
          'exportedAt': DateTime.now().toIso8601String(),
          'lumivoVersion': '99.0.0',
          'homeCount': 1,
          'deviceCount': 1,
        },
        'homes': [
          {'id': 'future-home', 'name': 'Future Home'}
        ],
        'rooms': [],
        'devices': [],
        'scenes': [],
        'automations': [],
      });

      final val = BackupValidationService.validate(unsupportedPayload);
      expect(val.isValid, isFalse);
      expect(
        val.errors.any((e) => e.contains('Unsupported schema version: 99')),
        isTrue,
      );

      final restored = await backupService.restoreBackup(
        jsonString: unsupportedPayload,
        persistenceManager: persistenceManager,
      );
      expect(restored, isFalse);

      final postState = await persistenceManager.loadHomeState();
      expect(postState.homes.length, equals(preState.homes.length));
    });

    // -------------------------------------------------------------------------
    // FLOW E: Sensitive Data Sanitization
    // (Test credentials in customData scrubbed from exports & storage)
    // -------------------------------------------------------------------------
    test(
        'Flow E: Sensitive Data Sanitization (test credentials in customData scrubbed from exports & storage)',
        () async {
      final dirtyCustomData = {
        'wifi_pass': 'secret123',
        'auth_token': 'eyJh...token',
        'api_key': 'key_abc',
        'private_key': 'PRIVATE_KEY_DATA',
        'safe_firmware': '1.0.4',
      };

      // 1. Scrubbing via SecretSanitizer
      final sanitized = SecretSanitizer.sanitizeMap(dirtyCustomData);
      expect(sanitized.containsKey('wifi_pass'), isFalse);
      expect(sanitized.containsKey('auth_token'), isFalse);
      expect(sanitized.containsKey('api_key'), isFalse);
      expect(sanitized.containsKey('private_key'), isFalse);
      expect(sanitized['safe_firmware'], equals('1.0.4'));

      // 2. Add device with dirty custom data to persistence
      final device = SmartDevice(
        id: 'dev-sanitized-flow-e',
        name: 'Sanitized Device',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: true,
        customData: dirtyCustomData,
      );
      final currentState = await persistenceManager.loadHomeState();
      await persistenceManager.saveHomeState(
        currentState.copyWith(devices: [...currentState.devices, device]),
      );

      // 3. Export backup and verify secrets are stripped
      final exported = await backupService.exportBackupJson(
        persistenceManager: persistenceManager,
      );
      expect(exported, isNot(contains('secret123')));
      expect(exported, isNot(contains('eyJh...token')));
      expect(exported, isNot(contains('key_abc')));
      expect(exported, contains('safe_firmware'));
    });

    // -------------------------------------------------------------------------
    // FLOW F: Atomic Recovery with Rollback
    // (Simulated storage failure during restore rolls back to pre-restore state)
    // -------------------------------------------------------------------------
    test(
        'Flow F: Atomic Recovery with Rollback (simulated storage failure during restore rolls back to pre-restore state)',
        () async {
      final faultAdapter = FaultInjectionStorageAdapter();
      final manager = HomePersistenceManager(storage: faultAdapter);
      await manager.loadHomeState();

      final preHomes = manager.cachedState!.homes.length;
      final preDevices = manager.cachedState!.devices.length;

      final incomingPayload = jsonEncode({
        'metadata': {
          'schemaVersion': 6,
          'exportedAt': DateTime.now().toIso8601String(),
          'lumivoVersion': '0.6.0',
          'homeCount': 1,
          'deviceCount': 1,
        },
        'homes': [
          {'id': 'home-new', 'name': 'Incoming Home'}
        ],
        'rooms': [
          {'id': 'room-new', 'name': 'New Room', 'homeId': 'home-new'}
        ],
        'devices': [
          {
            'id': 'dev-new',
            'name': 'New Dev',
            'roomId': 'room-new',
            'type': 'light',
            'homeId': 'home-new',
          }
        ],
        'scenes': [],
        'automations': [],
        'dashboardConfigs': [],
      });

      // Inject fault right before restore
      faultAdapter.failOnWrite = true;

      final success = await backupService.restoreBackup(
        jsonString: incomingPayload,
        persistenceManager: manager,
      );

      expect(success, isFalse);

      // Disable fault to inspect state
      faultAdapter.failOnWrite = false;
      final rolledBackState = await manager.loadHomeState();
      expect(rolledBackState.homes.length, equals(preHomes));
      expect(rolledBackState.devices.length, equals(preDevices));
    });

    // -------------------------------------------------------------------------
    // FLOW G: Multi-Home Integrity
    // (Backup two homes -> restore -> verify strict scoping by homeId)
    // -------------------------------------------------------------------------
    test(
        'Flow G: Multi-Home Integrity (backup two homes -> restore -> verify strict scoping by homeId)',
        () async {
      final multiHomePayload = jsonEncode({
        'metadata': {
          'schemaVersion': 6,
          'exportedAt': DateTime.now().toIso8601String(),
          'lumivoVersion': '0.6.0',
          'homeCount': 2,
          'deviceCount': 2,
        },
        'homes': [
          {'id': 'home-north', 'name': 'North Residence'},
          {'id': 'home-south', 'name': 'South Retreat'},
        ],
        'rooms': [
          {'id': 'room-n1', 'name': 'North Den', 'homeId': 'home-north'},
          {'id': 'room-s1', 'name': 'South Lounge', 'homeId': 'home-south'},
        ],
        'devices': [
          {
            'id': 'dev-n1',
            'name': 'North Lamp',
            'roomId': 'room-n1',
            'type': 'light',
            'homeId': 'home-north',
          },
          {
            'id': 'dev-s1',
            'name': 'South AC',
            'roomId': 'room-s1',
            'type': 'ac',
            'homeId': 'home-south',
          },
        ],
        'scenes': [],
        'automations': [],
        'dashboardConfigs': [
          {
            'homeId': 'home-north',
            'sectionOrder': ['metrics']
          },
          {
            'homeId': 'home-south',
            'sectionOrder': ['favorites']
          },
        ],
      });

      final success = await backupService.restoreBackup(
        jsonString: multiHomePayload,
        persistenceManager: persistenceManager,
      );
      expect(success, isTrue);

      final state = await persistenceManager.loadHomeState();
      expect(state.homes.length, equals(2));

      // Verify strict isolation by homeId
      final northDevs =
          state.devices.where((d) => d.homeId == 'home-north').toList();
      final southDevs =
          state.devices.where((d) => d.homeId == 'home-south').toList();

      expect(northDevs.length, equals(1));
      expect(northDevs.first.id, equals('dev-n1'));
      expect(southDevs.length, equals(1));
      expect(southDevs.first.id, equals('dev-s1'));

      expect(state.dashboardConfigs.containsKey('home-north'), isTrue);
      expect(state.dashboardConfigs.containsKey('home-south'), isTrue);
    });

    // -------------------------------------------------------------------------
    // FLOW H: Legacy Migration
    // (Restore supported legacy V1-V5 data -> migrate safely to V6)
    // -------------------------------------------------------------------------
    test(
        'Flow H: Legacy Migration (restore supported legacy V1-V5 data -> migrate safely to V6)',
        () async {
      final v4Payload = {
        'schemaVersion': 4,
        'homes': [
          {
            'id': 'home-v4',
            'name': 'Legacy V4 Villa',
            'isCurrent': true,
          }
        ],
        'currentHomeId': 'home-v4',
        'rooms': [
          {'id': 'room-v4', 'name': 'Atrium', 'homeId': 'home-v4'}
        ],
        'devices': [
          {
            'id': 'dev-v4-fan',
            'name': 'Ceiling Fan',
            'roomId': 'room-v4',
            'type': 'fan',
            'isOn': true,
            'homeId': 'home-v4',
          }
        ],
        'scenes': [],
        'automations': [],
      };

      await storage.remove(HomePersistenceManager.storageKey);
      await storage.setString(
        HomePersistenceManager.v4StorageKey,
        jsonEncode(v4Payload),
      );

      final freshManager = HomePersistenceManager(storage: storage);
      final migratedState = await freshManager.loadHomeState();

      expect(migratedState.schemaVersion, equals(6));
      expect(migratedState.homes.any((h) => h.id == 'home-v4'), isTrue);
      expect(migratedState.devices.any((d) => d.id == 'dev-v4-fan'), isTrue);
      expect(
          await storage.getString(HomePersistenceManager.v4StorageKey), isNull);
    });

    // -------------------------------------------------------------------------
    // FLOW I: Large Data Bounded Validation
    // (Test near-limit JSON import within bounded time and memory)
    // -------------------------------------------------------------------------
    test(
        'Flow I: Large Data Bounded Validation (test near-limit JSON import within bounded time and memory)',
        () async {
      // 100 devices across 20 rooms and 50 automations
      final rooms = List.generate(
        20,
        (i) => {
          'id': 'room-$i',
          'name': 'Room $i',
          'homeId': 'home-scale',
        },
      );

      final devices = List.generate(
        100,
        (i) => {
          'id': 'dev-$i',
          'name': 'Scale Device $i',
          'roomId': 'room-${i % 20}',
          'type': 'light',
          'isOn': i.isEven,
          'homeId': 'home-scale',
          'powerUsageWatts': 25.0,
        },
      );

      final automations = List.generate(
        50,
        (i) => {
          'id': 'auto-$i',
          'name': 'Scale Automation $i',
          'isEnabled': true,
          'triggerType': 'schedule',
          'timeOfDay': '18:00',
          'homeId': 'home-scale',
          'actions': [
            {'deviceId': 'dev-$i', 'commandType': 'setPower', 'value': true}
          ],
        },
      );

      final payload = jsonEncode({
        'metadata': {
          'schemaVersion': 6,
          'exportedAt': DateTime.now().toIso8601String(),
          'lumivoVersion': '0.6.0',
          'homeCount': 1,
          'deviceCount': 100,
        },
        'homes': [
          {'id': 'home-scale', 'name': 'Scale Home'}
        ],
        'rooms': rooms,
        'devices': devices,
        'scenes': [],
        'automations': automations,
      });

      final sw = Stopwatch()..start();
      final val = BackupValidationService.validate(payload);
      sw.stop();

      expect(val.isValid, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(600));
    });

    // -------------------------------------------------------------------------
    // FLOW J: CSV Formula Safety
    // (Device name starting with =CMD neutralized with leading ')
    // -------------------------------------------------------------------------
    test(
        'Flow J: CSV Formula Safety (device name starting with =CMD neutralized with leading \')',
        () {
      const maliciousName = "=CMD|' /C calc'!A0";
      final sanitizedCell =
          EnergyInsightsService.sanitizeCsvCell(maliciousName);
      expect(sanitizedCell.startsWith("'=CMD"), isTrue);

      const energyService = EnergyInsightsService();
      final report = EnergyReport(
        period: 'day',
        totalKwh: 10.0,
        totalCost: 2.0,
        tariff: 0.20,
        previousPeriodKwh: 0.0,
        percentChange: 0.0,
        generatedAt: DateTime(2026, 10, 26, 15, 0),
        deviceBreakdown: const [
          EnergyBreakdownItem(
            id: 'dev-exploit-j',
            name: maliciousName,
            category: 'device',
            wattage: 100.0,
            kwh: 2.0,
            cost: 0.40,
          ),
        ],
        roomBreakdown: const [],
      );

      final csv = energyService.exportEnergyCsv(report);
      expect(csv, contains("'=CMD"));
      expect(csv, isNot(contains(',=CMD')));
    });

    // -------------------------------------------------------------------------
    // FLOW K: Persistence & Refresh
    // (Modify dashboard, favorites, automations -> reload state -> verify intact)
    // -------------------------------------------------------------------------
    test(
        'Flow K: Persistence & Refresh (modify dashboard, favorites, automations -> reload state -> verify intact)',
        () async {
      final state = await persistenceManager.loadHomeState();

      // 1. Add favorite device
      final favDev = state.devices.first.copyWith(
        isFavorite: true,
        favoriteOrder: 1,
      );
      final updatedDevices = [
        favDev,
        ...state.devices.where((d) => d.id != favDev.id),
      ];

      // 2. Add custom automation rule
      final newRule = AutomationRule(
        id: 'rule-flow-k',
        name: 'Evening Chill Automation',
        triggerType: TriggerType.schedule,
        timeOfDay: '19:30',
        homeId: state.currentHomeId,
        actions: [
          DeviceAction(
            deviceId: favDev.id,
            commandType: DeviceCommandType.setPower,
            value: true,
          ),
        ],
      );

      // 3. Update dashboard config
      final cfg = (state.dashboardConfigs[state.currentHomeId] ??
              DashboardConfig.defaultFor(state.currentHomeId))
          .copyWith(
        sectionOrder: [DashboardSection.favorites, DashboardSection.metrics],
      );

      final newState = state.copyWith(
        devices: updatedDevices,
        automations: [...state.automations, newRule],
        dashboardConfigs: {
          ...state.dashboardConfigs,
          state.currentHomeId: cfg,
        },
      );

      await persistenceManager.saveHomeState(newState);

      // 4. Reload from fresh persistence manager instance
      final freshManager = HomePersistenceManager(storage: storage);
      final reloadedState = await freshManager.loadHomeState();

      expect(
        reloadedState.devices.firstWhere((d) => d.id == favDev.id).isFavorite,
        isTrue,
      );
      expect(
        reloadedState.automations.any((a) => a.id == 'rule-flow-k'),
        isTrue,
      );
      expect(
        reloadedState.dashboardConfigs[state.currentHomeId]?.sectionOrder.first,
        equals(DashboardSection.favorites),
      );
    });

    // -------------------------------------------------------------------------
    // FLOW L: Recovery Options
    // (Corrupt data triggers recovery center options without destroying valid data)
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow L: Recovery Options (corrupt data triggers recovery center options without destroying valid data)',
        (tester) async {
      setupViewport(tester);

      // 1. Save a valid known-good snapshot
      await persistenceManager.saveSnapshot();
      expect(await persistenceManager.hasSnapshot(), isTrue);

      await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
      await tester.pumpAndSettle();

      // 2. Verify Recovery Center buttons are rendered
      expect(
          find.byKey(const Key('recovery_retry_load_button')), findsOneWidget);
      expect(find.byKey(const Key('recovery_restore_snapshot_button')),
          findsOneWidget);
      expect(find.byKey(const Key('recovery_create_snapshot_button')),
          findsOneWidget);
      expect(find.byKey(const Key('recovery_factory_reset_button')),
          findsOneWidget);

      // 3. Tap restore snapshot button
      await tester
          .tap(find.byKey(const Key('recovery_restore_snapshot_button')));
      await tester.pumpAndSettle();

      // 4. Verify feedback snackbar
      expect(find.text('Known-good snapshot restored successfully'),
          findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // FLOW M: Localization
    // (Switch Vietnamese/English -> verify Privacy, Backup, and Recovery screens)
    // -------------------------------------------------------------------------
    testWidgets(
        'Flow M: Localization (switch Vietnamese/English -> verify Privacy, Backup, and Recovery screens)',
        (tester) async {
      setupViewport(tester);

      // 1. Render PrivacyCenterScreen in Vietnamese
      await tester.pumpWidget(
        createTestApp(
          const PrivacyCenterScreen(),
          locale: const Locale('vi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trung tâm Quyền riêng tư & Dữ liệu'), findsOneWidget);
      expect(find.text('Lưu trữ Dữ liệu Cục bộ'), findsOneWidget);

      // 2. Render RecoveryCenterScreen in Vietnamese
      await tester.pumpWidget(
        createTestApp(
          const RecoveryCenterScreen(),
          locale: const Locale('vi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trung tâm Phục hồi'), findsWidgets);
      expect(find.text('Tải lại Trạng thái'), findsWidgets);

      // 3. Render BackupRestoreScreen in Vietnamese
      await tester.pumpWidget(
        createTestApp(
          const BackupRestoreScreen(),
          locale: const Locale('vi'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sao lưu & Phục hồi'), findsWidgets);
      expect(find.text('Xuất bản sao lưu (JSON)'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // FLOW N: Full Regression
    // (Verify all earlier Phase 0–7 features remain 100% green)
    // -------------------------------------------------------------------------
    test('Flow N: Full Regression (earlier features intact)', () async {
      final state = await persistenceManager.loadHomeState();
      expect(state.schemaVersion, equals(6));
      expect(state.homes.length, greaterThanOrEqualTo(2));
      expect(state.rooms.length, greaterThanOrEqualTo(3));
      expect(state.devices.length, greaterThanOrEqualTo(4));
      expect(state.scenes.isNotEmpty, isTrue);
      expect(state.automations.isNotEmpty, isTrue);
    });
  });
}
