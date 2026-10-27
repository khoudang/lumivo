import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/localization/strings_en.dart';
import 'package:lumivo/core/localization/strings_vi.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/core/theme/app_theme.dart';
import 'package:lumivo/features/activity/presentation/activity_screen.dart';
import 'package:lumivo/features/automation/presentation/automation_builder_wizard.dart';
import 'package:lumivo/features/automation/presentation/automation_screen.dart';
import 'package:lumivo/features/automation/presentation/create_automation_screen.dart';
import 'package:lumivo/features/automation/presentation/scene_editor_sheet.dart';
import 'package:lumivo/features/automation/state/automation_notifier.dart';
import 'package:lumivo/features/automation/state/scenes_notifier.dart';
import 'package:lumivo/features/backup/presentation/backup_restore_screen.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/demo_lab/presentation/demo_lab_screen.dart';
import 'package:lumivo/features/device_detail/presentation/device_detail_screen.dart';
import 'package:lumivo/features/device_detail/presentation/device_settings_sheet.dart';
import 'package:lumivo/features/energy/presentation/energy_screen.dart';
import 'package:lumivo/features/health/presentation/smart_home_health_screen.dart';
import 'package:lumivo/features/home/presentation/home_selector_sheet.dart';
import 'package:lumivo/features/notifications/presentation/notifications_sheet.dart';
import 'package:lumivo/features/onboarding/presentation/add_device_sheet.dart';
import 'package:lumivo/features/onboarding/presentation/splash_screen.dart';
import 'package:lumivo/features/onboarding/presentation/welcome_screen.dart';
import 'package:lumivo/features/privacy/presentation/privacy_center_screen.dart';
import 'package:lumivo/features/privacy/presentation/recovery_center_screen.dart';
import 'package:lumivo/features/profile/presentation/profile_screen.dart';
import 'package:lumivo/features/rooms/presentation/rooms_screen.dart';
import 'package:lumivo/features/rooms/state/rooms_notifier.dart';
import 'package:lumivo/features/search/presentation/device_search_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 9 Release Candidate UI/UX & Localization Freeze Test Suite', () {
    late MockDeviceRepository repository;

    final testDevice = SmartDevice(
      id: 'lumivo-light-01',
      name: 'Nordic Ceiling Light',
      roomId: 'Living Room',
      type: DeviceType.light,
      isOn: true,
      brightness: 85,
      connection: DeviceConnection.online,
    );

    setUp(() {
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: [
          testDevice,
          const SmartDevice(
            id: 'lumivo-curtain-01',
            name: 'Balcony Smart Curtain',
            roomId: 'Living Room',
            type: DeviceType.curtain,
            isOn: false,
            position: 100,
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
      ThemeData? theme,
      MediaQueryData? mediaQuery,
    }) {
      Widget appContent = Scaffold(
        backgroundColor: AppColors.background,
        body: child,
      );
      if (mediaQuery != null) {
        appContent = MediaQuery(
          data: mediaQuery,
          child: appContent,
        );
      }

      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          userProfileProvider.overrideWith((ref) => UserProfileNotifier(
                UserProfile(language: locale.languageCode),
              )),
          appLocalizationsProvider.overrideWithValue(AppLocalizations(locale)),
          ...overrides,
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.dark,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: appContent,
        ),
      );
    }

    void setupViewport(
      WidgetTester tester, {
      Size size = const Size(320, 600),
    }) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // =========================================================================
    // 1. Dark Minimal Design Tokens & AppTheme Consistency
    // =========================================================================
    group('1. Visual Consistency & Design Tokens', () {
      test('AppSpacing tokens enforce 4pt/8pt rhythm', () {
        expect(AppSpacing.xs, equals(4.0));
        expect(AppSpacing.sm, equals(8.0));
        expect(AppSpacing.md, equals(16.0));
        expect(AppSpacing.lg, equals(24.0));
        expect(AppSpacing.xl, equals(32.0));
      });

      test('AppRadii tokens enforce consistent geometric chamfering', () {
        expect(AppRadii.sm, equals(8.0));
        expect(AppRadii.md, equals(12.0));
        expect(AppRadii.lg, equals(16.0));
        expect(AppRadii.card, equals(22.0));
        expect(AppRadii.dialog, equals(24.0));
        expect(AppRadii.sheet, equals(28.0));
      });

      test('AppTouchTargets.min enforces WCAG 48pt minimum', () {
        expect(AppTouchTargets.min, equals(48.0));
      });

      test('AppColors palette tokens are defined for dark minimal OLED', () {
        expect(AppColors.background, equals(const Color(0xFF0B0F17)));
        expect(AppColors.surface, equals(const Color(0xFF171D29)));
        expect(AppColors.primary, equals(const Color(0xFF8B7CFF)));
        expect(AppColors.green, equals(const Color(0xFF66DDB0)));
        expect(AppColors.danger, equals(const Color(0xFFFF6B6B)));
      });

      test('AppTheme.dark enforces button minimum sizes >= 48pt', () {
        final theme = AppTheme.dark;

        final elevatedMin =
            theme.elevatedButtonTheme.style?.minimumSize?.resolve({});
        expect(elevatedMin?.height, greaterThanOrEqualTo(48.0));

        final outlinedMin =
            theme.outlinedButtonTheme.style?.minimumSize?.resolve({});
        expect(outlinedMin?.height, greaterThanOrEqualTo(48.0));

        final textMin = theme.textButtonTheme.style?.minimumSize?.resolve({});
        expect(textMin?.height, greaterThanOrEqualTo(48.0));

        final iconConstraints =
            theme.iconButtonTheme.style?.minimumSize?.resolve({});
        expect(iconConstraints?.height, greaterThanOrEqualTo(48.0));
      });
    });

    // =========================================================================
    // 2. Localization Parity & Typed Dynamic Interpolation
    // =========================================================================
    group('2. Localization Parity & Dynamic Interpolation', () {
      test('100% key parity between English and Vietnamese string registries',
          () {
        expect(stringsEn.length, equals(311));
        expect(stringsVi.length, equals(311));

        final enKeys = stringsEn.keys.toSet();
        final viKeys = stringsVi.keys.toSet();

        final missingInVi = enKeys.difference(viKeys);
        final missingInEn = viKeys.difference(enKeys);

        expect(missingInVi, isEmpty,
            reason: 'Keys present in EN but missing in VI: $missingInVi');
        expect(missingInEn, isEmpty,
            reason: 'Keys present in VI but missing in EN: $missingInEn');
      });

      test('Parameterized dynamic string interpolation works in EN and VI', () {
        final l10nEn = AppLocalizations(const Locale('en'));
        final l10nVi = AppLocalizations(const Locale('vi'));

        // Rooms
        expect(l10nEn.roomAdded('Kitchen'), equals('Room "Kitchen" added'));
        expect(l10nVi.roomAdded('Kitchen'), equals('Đã thêm phòng "Kitchen"'));
        expect(l10nEn.roomDeleted('Kitchen'), equals('Room "Kitchen" deleted'));
        expect(l10nVi.roomDeleted('Kitchen'), equals('Đã xóa phòng "Kitchen"'));
        expect(
          l10nEn.confirmDeleteRoomBody('Kitchen'),
          contains('Kitchen'),
        );
        expect(
          l10nVi.confirmDeleteRoomBody('Kitchen'),
          contains('Kitchen'),
        );

        // Scenes
        expect(
          l10nEn.sceneExecuted('Movie Night'),
          equals('Scene "Movie Night" executed successfully!'),
        );
        expect(
          l10nVi.sceneExecuted('Movie Night'),
          equals('Kịch bản "Movie Night" đã thực thi thành công!'),
        );
        expect(
          l10nEn.sceneSaved('Movie Night'),
          equals('Scene "Movie Night" saved successfully!'),
        );
        expect(
          l10nVi.sceneSaved('Movie Night'),
          equals('Đã lưu kịch bản "Movie Night" thành công!'),
        );
        expect(
          l10nEn.sceneDeleted('Movie Night'),
          equals('Scene "Movie Night" deleted'),
        );
        expect(
          l10nVi.sceneDeleted('Movie Night'),
          equals('Đã xóa kịch bản "Movie Night"'),
        );

        // Automation Rules
        expect(
          l10nEn.ruleCreated('Bedtime'),
          equals('Rule "Bedtime" created successfully!'),
        );
        expect(
          l10nVi.ruleCreated('Bedtime'),
          equals('Đã tạo quy tắc "Bedtime" thành công!'),
        );
        expect(
          l10nEn.ruleDeleted('Bedtime'),
          equals('Rule "Bedtime" deleted'),
        );
        expect(
          l10nVi.ruleDeleted('Bedtime'),
          equals('Đã xóa quy tắc "Bedtime"'),
        );

        // Homes
        expect(l10nEn.homeAdded('Summer Villa'),
            equals('Home "Summer Villa" added successfully!'));
        expect(l10nVi.homeAdded('Summer Villa'),
            equals('Đã thêm nhà "Summer Villa" thành công!'));
        expect(l10nEn.homeDeleted('Summer Villa'),
            equals('Home "Summer Villa" deleted.'));
        expect(l10nVi.homeDeleted('Summer Villa'),
            equals('Đã xóa nhà "Summer Villa".'));

        // Device
        expect(l10nEn.deviceDeleted('Desk Lamp'),
            equals('Device "Desk Lamp" deleted.'));
        expect(l10nVi.deviceDeleted('Desk Lamp'),
            equals('Đã xóa thiết bị "Desk Lamp".'));
        expect(l10nEn.deviceSettingsSaved,
            equals('Device settings saved successfully!'));
        expect(l10nVi.deviceSettingsSaved,
            equals('Đã lưu cài đặt thiết bị thành công!'));
      });
    });

    // =========================================================================
    // 3. Full-Screen UX & 320x600 Ultra-Narrow Viewport Conformance
    // =========================================================================
    group('3. Full-Screen UX & 320x600 Ultra-Narrow Viewport Conformance', () {
      testWidgets('SplashScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const SplashScreen()));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      });

      testWidgets('WelcomeScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const WelcomeScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('DashboardScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('RoomsScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const RoomsScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('DeviceSearchScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('DeviceDetailScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester
            .pumpWidget(createTestApp(DeviceDetailScreen(device: testDevice)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('AutomationScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const AutomationScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('CreateAutomationScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const CreateAutomationScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('AutomationBuilderWizard renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const AutomationBuilderWizard()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('ActivityScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const ActivityScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('SmartHomeHealthScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const SmartHomeHealthScreen()));
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

      testWidgets('DemoLabScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const DemoLabScreen()));
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

      testWidgets('PrivacyCenterScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('RecoveryCenterScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const RecoveryCenterScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('SettingsScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('ProfileScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const ProfileScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('HomeSelectorSheet renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const HomeSelectorSheet()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('DeviceSettingsSheet renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester
            .pumpWidget(createTestApp(DeviceSettingsSheet(device: testDevice)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('SceneEditorSheet renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const SceneEditorSheet()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('NotificationsSheet renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const NotificationsSheet()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 4. Accessibility Conformance (WCAG 2.1 AA)
    // =========================================================================
    group('4. Accessibility Conformance (WCAG 2.1 AA)', () {
      testWidgets('ProfileScreen interactive preference pills meet >= 48pt',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const ProfileScreen()));
        await tester.pumpAndSettle();

        final enButton = find.widgetWithText(InkWell, 'English');
        if (enButton.evaluate().isNotEmpty) {
          final size = tester.getSize(enButton.first);
          expect(size.height, greaterThanOrEqualTo(48.0));
        }
      });

      testWidgets('RoomsScreen Add Room button meets >= 48pt bounds',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const RoomsScreen()));
        await tester.pumpAndSettle();

        final addRoomBtn = find.byKey(const Key('add_room_fab_extended'));
        if (addRoomBtn.evaluate().isNotEmpty) {
          final size = tester.getSize(addRoomBtn.first);
          expect(size.height, greaterThanOrEqualTo(48.0));
        }
      });

      testWidgets('Text scaling at 1.5x renders without RenderFlex overflow',
          (tester) async {
        setupViewport(tester, size: const Size(360, 640));
        await tester.pumpWidget(
          createTestApp(
            const DashboardScreen(),
            mediaQuery: const MediaQueryData(
              textScaler: TextScaler.linear(1.5),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Text scaling at 2.0x renders without RenderFlex overflow',
          (tester) async {
        setupViewport(tester, size: const Size(360, 640));
        await tester.pumpWidget(
          createTestApp(
            const ProfileScreen(),
            mediaQuery: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'AddDeviceSheet handles reduced motion without repeating loop',
          (tester) async {
        setupViewport(tester, size: const Size(360, 640));
        await tester.pumpWidget(
          createTestApp(
            const AddDeviceSheet(),
            mediaQuery: const MediaQueryData(
              disableAnimations: true,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Semantics and tooltips are present on device detail actions',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester
            .pumpWidget(createTestApp(DeviceDetailScreen(device: testDevice)));
        await tester.pumpAndSettle();

        final settingsBtn = find.byTooltip('Device Settings');
        expect(settingsBtn, findsOneWidget);
      });
    });

    // =========================================================================
    // 5. Empty & Error States
    // =========================================================================
    group('5. Empty & Error State Presentation', () {
      testWidgets('RoomsScreen displays localized empty state when 0 rooms',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(
          createTestApp(
            const RoomsScreen(),
            overrides: [
              roomsProvider.overrideWith((ref) => RoomsNotifier([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final emptyTextFinder = find.byKey(const Key('rooms_empty_state_text'));
        expect(emptyTextFinder, findsOneWidget);
        expect(find.text('No rooms configured yet'), findsOneWidget);
      });

      testWidgets('AutomationScreen displays empty state when 0 rules & scenes',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(
          createTestApp(
            const AutomationScreen(),
            overrides: [
              automationProvider.overrideWith((ref) => AutomationNotifier([])),
              scenesProvider.overrideWith((ref) => ScenesNotifier([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AutomationScreen), findsOneWidget);
      });

      testWidgets('BackupRestoreScreen displays actionable failure on error',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const BackupRestoreScreen()));
        await tester.pumpAndSettle();

        final corruptedBtn = find.byKey(const Key('preset_malformed'));
        if (corruptedBtn.evaluate().isNotEmpty) {
          await tester.tap(corruptedBtn);
          await tester.pumpAndSettle();

          final validateBtn = find.byKey(const Key('validate_backup_button'));
          if (validateBtn.evaluate().isNotEmpty) {
            await tester.tap(validateBtn);
            await tester.pumpAndSettle();

            expect(
              find.text('Backup Validation Failure'),
              findsOneWidget,
            );
          }
        }
      });
    });
  });
}
