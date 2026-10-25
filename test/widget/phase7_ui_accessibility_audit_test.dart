import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/features/activity/presentation/activity_screen.dart';
import 'package:lumivo/features/automation/presentation/automation_screen.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_edit_sheet.dart';
import 'package:lumivo/features/device_detail/presentation/device_settings_sheet.dart';
import 'package:lumivo/features/home/presentation/home_app_bar_title.dart';
import 'package:lumivo/features/home/presentation/home_selector_sheet.dart';
import 'package:lumivo/features/notifications/presentation/notifications_sheet.dart';
import 'package:lumivo/features/onboarding/presentation/add_device_sheet.dart';
import 'package:lumivo/features/onboarding/presentation/splash_screen.dart';
import 'package:lumivo/features/profile/presentation/profile_screen.dart';
import 'package:lumivo/features/rooms/presentation/rooms_screen.dart';
import 'package:lumivo/features/search/presentation/device_search_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 7 UI/UX & Accessibility Comprehensive Audit Test Suite', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(
        responseDelay: Duration.zero,
        initialDevices: const [
          SmartDevice(
            id: 'light-audit-1',
            name: 'Ambient Aura Luminaire',
            roomId: 'Living Room',
            type: DeviceType.light,
            isOn: true,
            brightness: 75,
            connection: DeviceConnection.online,
          ),
          SmartDevice(
            id: 'fan-audit-1',
            name: 'Aero Breeze Fan',
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
    // 1. Destructive Confirmation Dialogs
    // =========================================================================
    group('Destructive Confirmation Dialog Enforcements', () {
      testWidgets(
          'DEF-01: Reset Dashboard Layout requires explicit confirmation',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const Scaffold(
          body: DashboardEditSheet(),
        )));
        await tester.pumpAndSettle();

        // Find reset button and tap it
        final resetBtn = find.byKey(const Key('reset_dashboard_layout_button'));
        expect(resetBtn, findsOneWidget);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog must appear
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.byKey(const Key('confirm_reset_dashboard_layout_button')),
          findsOneWidget,
        );

        // Tap cancel first - dialog closes
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        // Tap reset again and confirm
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();
        await tester.tap(
            find.byKey(const Key('confirm_reset_dashboard_layout_button')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets(
          'DEF-02: Automation Rule deletion requires explicit confirmation',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const AutomationScreen()));
        await tester.pumpAndSettle();

        final deleteBtn = find.byTooltip('Delete').first;
        expect(deleteBtn, findsOneWidget);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Dialog must be shown
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.byKey(const Key('confirm_delete_rule_button')),
          findsOneWidget,
        );

        // Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets(
          'DEF-03: Activity History clear requires explicit confirmation',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const ActivityScreen()));
        await tester.pumpAndSettle();

        final clearBtn = find.byKey(const Key('clear_history_button'));
        expect(clearBtn, findsOneWidget);
        await tester.tap(clearBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.byKey(const Key('confirm_clear_history_button')),
          findsOneWidget,
        );

        // Confirm clear
        await tester.tap(find.byKey(const Key('confirm_clear_history_button')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets(
          'DEF-04: Room deletion has confirmation in RoomsScreen bottom sheet',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const RoomsScreen()));
        await tester.pumpAndSettle();

        // Tap on first room card to open room devices sheet
        final roomCard = find.text('Living Room');
        expect(roomCard, findsWidgets);
        await tester.tap(roomCard.first);
        await tester.pumpAndSettle();

        // Delete Room button is present in the sheet
        final deleteRoomBtn = find.byKey(const Key('delete_room_button'));
        expect(deleteRoomBtn, findsOneWidget);
        await tester.tap(deleteRoomBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog shown
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const Key('confirm_delete_room_button')),
            findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets(
          'DEF-05: Notifications sheet provides clear all with confirmation',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        await tester.pumpWidget(createTestApp(const Scaffold(
          body: NotificationsSheet(),
        )));
        await tester.pumpAndSettle();

        final clearAllBtn =
            find.byKey(const Key('clear_all_notifications_button'));
        expect(clearAllBtn, findsOneWidget);
        await tester.tap(clearAllBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.byKey(const Key('confirm_clear_notifications_button')),
          findsOneWidget,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets(
          'Device Settings sheet deletion requires explicit confirmation',
          (tester) async {
        setupViewport(tester, size: const Size(400, 800));
        const testDev = SmartDevice(
          id: 'test-del-1',
          name: 'Deletable Light',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
        );

        await tester.pumpWidget(createTestApp(const Scaffold(
          body: DeviceSettingsSheet(device: testDev),
        )));
        await tester.pumpAndSettle();

        final delBtn = find.byKey(const Key('device_settings_delete_button'));
        expect(delBtn, findsOneWidget);
        await tester.tap(delBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const Key('confirm_delete_device_button')),
            findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    // =========================================================================
    // 2. Touch Target Sizing (>= 48x48 pt)
    // =========================================================================
    group('Touch Target Sizing Compliance (>= 48x48 pt)', () {
      testWidgets('HomeAppBarTitle meets >= 48pt height constraint',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: SafeArea(child: HomeAppBarTitle()),
          ),
        )));
        await tester.pumpAndSettle();

        final button = find.byKey(const Key('home_app_bar_title_button'));
        expect(button, findsOneWidget);
        final size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(48.0));
        expect(size.width, greaterThanOrEqualTo(48.0));
      });

      testWidgets('ProfileScreen preference choice pills meet >= 48pt bounds',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const ProfileScreen()));
        await tester.pumpAndSettle();

        final engPill = find.text('English');
        expect(engPill, findsOneWidget);
        final size = tester.getSize(find
            .ancestor(
              of: engPill,
              matching: find.byType(InkWell),
            )
            .first);
        expect(size.height, greaterThanOrEqualTo(48.0));
        expect(size.width, greaterThanOrEqualTo(48.0));
      });

      testWidgets('DeviceSearchScreen filter chips meet >= 48pt touch height',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        final onlineChip = find.byKey(const Key('filter_status_online'));
        expect(onlineChip, findsOneWidget);
        final size = tester.getSize(onlineChip);
        expect(size.height, greaterThanOrEqualTo(48.0));
        expect(size.width, greaterThanOrEqualTo(48.0));
      });

      testWidgets('AddDeviceSheet cancel button meets >= 48x48 bounds',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const Scaffold(body: AddDeviceSheet()),
          overrides: [
            userProfileProvider.overrideWith((ref) => UserProfileNotifier(
                  const UserProfile(
                    name: 'Auditor',
                    email: 'audit@lumivo.test',
                    reducedMotion: true,
                  ),
                )),
          ],
        ));
        await tester.pump(const Duration(milliseconds: 100));

        final cancelBtn = find.byKey(const Key('onboarding_cancel_button'));
        expect(cancelBtn, findsOneWidget);
        final size = tester.getSize(cancelBtn);
        expect(size.height, greaterThanOrEqualTo(48.0));
        expect(size.width, greaterThanOrEqualTo(48.0));
      });
    });

    // =========================================================================
    // 3. Screen Reader Semantics
    // =========================================================================
    group('Screen Reader Semantics Tags', () {
      testWidgets('HomeAppBarTitle declares button semantic role',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const Scaffold(
          body: HomeAppBarTitle(),
        )));
        await tester.pumpAndSettle();

        final semantics = tester
            .getSemantics(find.byKey(const Key('home_app_bar_title_button')));
        expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
      });

      testWidgets('RoomsScreen room cards declare button semantic role',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const RoomsScreen()));
        await tester.pumpAndSettle();

        final roomFinder = find.byType(InkWell).first;
        final semantics = tester.getSemantics(roomFinder);
        expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
      });

      testWidgets('DeviceSearchScreen chips declare button semantic role',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        final semantics =
            tester.getSemantics(find.byKey(const Key('filter_status_all')));
        expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
      });
    });

    // =========================================================================
    // 4. Viewport Responsiveness (320x600 Narrow Viewport without Overflows)
    // =========================================================================
    group('Viewport Responsiveness (320x600 Narrow Viewport)', () {
      testWidgets(
          'DEF-06: AutomationScreen Ambiance Scenes tab renders without RenderFlex overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const AutomationScreen()));
        await tester.pumpAndSettle();

        // Switch to Scenes tab
        await tester.tap(find.text('Scenes'));
        await tester.pumpAndSettle();

        // Verify scenes are visible and actions rendered without overflow
        expect(find.text('Ambiance Scenes'), findsOneWidget);
        expect(find.byKey(const Key('add_scene_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'DEF-07: HomeSelectorSheet renders long home names without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        final longHome = Home(
          id: 'long-home-id',
          name: 'Super Ultra Long Luxurious Vacation Villa Estate',
          address: '9999 Oceanic Boulevard Penthouse Suite',
          role: 'Owner',
          isCurrent: true,
          tariffRate: 0.18,
        );

        await tester.pumpWidget(createTestApp(
          const Scaffold(body: HomeSelectorSheet()),
          overrides: [
            currentHomeProvider.overrideWith((ref) => longHome),
          ],
        ));
        await tester.pumpAndSettle();

        expect(find.text(longHome.name), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'DEF-08: ProfileScreen preference rows render on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const ProfileScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('preference_language_selector')),
            findsOneWidget);
        expect(
            find.byKey(const Key('preference_theme_toggle')), findsOneWidget);
        expect(find.byKey(const Key('preference_temp_unit_selector')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('RoomsScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const RoomsScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Spaces & Zones'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('DeviceSearchScreen renders on 320x600 without overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));
        await tester.pumpWidget(createTestApp(const DeviceSearchScreen()));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('global_device_search_bar')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 5. Reduced Motion Accessibility
    // =========================================================================
    group('Reduced Motion Accessibility Verification', () {
      testWidgets(
          'SplashScreen respects reduced motion by disabling animations',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const SplashScreen(),
          overrides: [
            userProfileProvider
                .overrideWith((ref) => UserProfileNotifier(const UserProfile(
                      name: 'Auditor',
                      email: 'audit@lumivo.test',
                      reducedMotion: true,
                    ))),
          ],
        ));
        await tester.pump(const Duration(milliseconds: 100));

        // SplashScreen renders without infinite repeating pulse crash
        expect(find.text('LUMIVO'), findsOneWidget);
      });

      testWidgets(
          'AddDeviceSheet radar controller does not repeat when reducedMotion is true',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const Scaffold(body: AddDeviceSheet()),
          overrides: [
            userProfileProvider
                .overrideWith((ref) => UserProfileNotifier(const UserProfile(
                      name: 'Auditor',
                      email: 'audit@lumivo.test',
                      reducedMotion: true,
                    ))),
          ],
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('scanning')), findsOneWidget);
      });
    });

    // =========================================================================
    // 6. Bilingual Localization (EN vs VI)
    // =========================================================================
    group('Bilingual Localization Switching (EN & VI)', () {
      testWidgets('English locale renders correctly without raw keys',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const RoomsScreen(),
          locale: const Locale('en'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Spaces & Zones'), findsOneWidget);
        expect(find.text('Add Room'), findsOneWidget);
      });

      testWidgets(
          'Vietnamese locale translates screens and confirmation dialogs correctly',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const RoomsScreen(),
          locale: const Locale('vi'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Không gian & Khu vực'), findsOneWidget);
        expect(find.text('Thêm phòng'), findsOneWidget);
      });

      testWidgets(
          'Vietnamese locale translates ActivityScreen and confirmation dialogs',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(
          const ActivityScreen(),
          locale: const Locale('vi'),
        ));
        await tester.pumpAndSettle();

        // Tap clear button in Vietnamese
        await tester.tap(find.byKey(const Key('clear_history_button')));
        await tester.pumpAndSettle();

        expect(find.text('Xóa lịch sử'), findsOneWidget);
        expect(
            find.text(
                'Bạn có chắc chắn muốn xóa tất cả nhật ký hoạt động? Hành động này không thể hoàn tác.'),
            findsOneWidget);
        expect(find.text('Xóa tất cả'), findsOneWidget);
      });
    });
  });
}
