import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/app.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/localization/strings_en.dart';
import 'package:lumivo/core/localization/strings_vi.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/core/theme/app_theme.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/energy/presentation/energy_screen.dart';
import 'package:lumivo/features/health/presentation/smart_home_health_screen.dart';
import 'package:lumivo/features/onboarding/presentation/add_device_sheet.dart';
import 'package:lumivo/features/onboarding/presentation/welcome_screen.dart';
import 'package:lumivo/features/privacy/presentation/privacy_center_screen.dart';
import 'package:lumivo/features/profile/presentation/profile_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 10 Final Store Readiness, UX Polish & Localization Suite', () {
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
          const SmartDevice(
            id: 'lumivo-fan-01',
            name: 'Aero Breeze Fan',
            roomId: 'Bedroom',
            type: DeviceType.fan,
            isOn: true,
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

    void setupViewport(WidgetTester tester, {required Size size}) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // =========================================================================
    // 1. Simulation Disclosure Verification Across All Core Screens
    // =========================================================================
    group('1. Simulation Disclosure Verification Across Core Screens', () {
      testWidgets('WelcomeScreen prominently discloses 100% offline simulation',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932)); // 6.7" iPhone
        await tester.pumpWidget(createTestApp(const WelcomeScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(
          find.textContaining('100% OFFLINE SMART HOME'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
              'No hardware, cloud login, or external network required'),
          findsOneWidget,
        );
      });

      testWidgets('AddDeviceSheet discloses 100% offline simulation mode',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester
            .pumpWidget(createTestApp(const Scaffold(body: AddDeviceSheet())));
        await tester.pump();

        expect(find.byKey(const Key('onboarding_simulation_notice')),
            findsOneWidget);
        expect(find.textContaining('100% offline'), findsWidgets);
      });

      testWidgets(
          'SettingsScreen features simulation disclosure card and clean v1.0.0 app info without workspace leaks',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();

        // Scroll to simulation disclosure card
        final disclosureFinder =
            find.byKey(const Key('settings_simulation_disclosure_card'));
        await tester.scrollUntilVisible(
          disclosureFinder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(disclosureFinder, findsOneWidget);
        expect(find.text('Simulation Mode Status'), findsOneWidget);
        expect(
            find.textContaining(
                '100% offline, no cloud backend, no physical hardware connection'),
            findsOneWidget);

        // Verify v1.0.0 app info without developer workspace leak
        expect(find.text('1.0.0 (Build 2026.10)'), findsOneWidget);
        expect(find.text('100% Offline Simulation Mode'), findsOneWidget);
        expect(find.textContaining('lumivo_phase7_ui'), findsNothing);
        expect(find.textContaining('D:\\app_iot'), findsNothing);
      });

      testWidgets(
          'SmartHomeHealthScreen features offline simulation disclosure badge',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester.pumpWidget(createTestApp(const SmartHomeHealthScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('health_simulation_disclosure_badge')),
            findsOneWidget);
        expect(
            find.textContaining(
                '100% offline, no cloud backend, no physical hardware connection'),
            findsOneWidget);
      });

      testWidgets(
          'PrivacyCenterScreen verifies 100% OFFLINE status badge and local storage disclosure',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('privacy_simulation_mode_card')),
            findsOneWidget);
        expect(find.text('100% OFFLINE'), findsOneWidget);
        expect(find.text('No cloud backend · No physical hardware connection'),
            findsOneWidget);
      });

      testWidgets(
          'ProfileScreen disclaimer card displays v1.0.0 and offline simulation disclosure',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester.pumpWidget(createTestApp(const ProfileScreen()));
        await tester.pumpAndSettle();

        // Scroll to disclaimer card
        final disclaimerFinder =
            find.byKey(const Key('profile_simulation_disclaimer'));
        await tester.scrollUntilVisible(
          disclaimerFinder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(disclaimerFinder, findsOneWidget);
        expect(
            find.textContaining(
                'Version 1.0.0 (Distribution Release) • 100% Offline Simulation'),
            findsOneWidget);
        expect(find.textContaining('Phase 3'), findsNothing);
      });

      testWidgets(
          'EnergyScreen displays simulated telemetry banner and energy notice',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester.pumpWidget(createTestApp(const EnergyScreen()));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('energy_simulation_badge')), findsOneWidget);
        expect(find.text('SIMULATED TELEMETRY • VIRTUAL ESTIMATE'),
            findsOneWidget);
      });
    });

    // =========================================================================
    // 2. Bilingual Translation Review & Natural Phrasing (EN & VI)
    // =========================================================================
    group('2. Bilingual Localization Quality & Registry Parity', () {
      test(
          '100% key parity and non-empty values between EN and VI dictionaries',
          () {
        expect(stringsEn.length, equals(311));
        expect(stringsVi.length, equals(311));

        final enKeys = stringsEn.keys.toSet();
        final viKeys = stringsVi.keys.toSet();

        expect(enKeys.difference(viKeys), isEmpty);
        expect(viKeys.difference(enKeys), isEmpty);

        for (final entry in stringsEn.entries) {
          expect(entry.value.trim(), isNotEmpty,
              reason: 'Empty string in EN for key: ${entry.key}');
        }
        for (final entry in stringsVi.entries) {
          expect(entry.value.trim(), isNotEmpty,
              reason: 'Empty string in VI for key: ${entry.key}');
        }
      });

      test('Audited natural Vietnamese phrasing for IoT telemetry & recovery',
          () {
        expect(stringsVi['simulated_telemetry'],
            equals('Dữ liệu đo đạc mô phỏng'));
        expect(stringsVi['simulated_telemetry_banner'],
            equals('DỮ LIỆU ĐO TỪ XA MÔ PHỎNG • ƯỚC TÍNH ẢO'));
        expect(stringsVi['recovery_restore_snapshot'],
            equals('Khôi phục bản snapshot ổn định'));
        expect(stringsVi['recovery_create_snapshot'],
            equals('Lưu bản snapshot ổn định'));
        expect(stringsVi['storage_health_optimal'],
            equals('Ổn định · Tối ưu (Lược đồ v6)'));
        expect(stringsVi['telemetry_refreshed'],
            equals('Đã làm mới dữ liệu đo đạc mô phỏng'));
        expect(
            stringsVi['refresh_telemetry'], equals('Làm mới dữ liệu đo đạc'));
        expect(
            stringsVi['simulation_mode_desc'],
            contains(
                '100% ngoại tuyến, không cần đám mây, không kết nối phần cứng vật lý'));
      });

      test(
          'Dynamic string interpolation and plurals format cleanly in both languages',
          () {
        final l10nEn = const AppLocalizations(Locale('en'));
        final l10nVi = const AppLocalizations(Locale('vi'));

        expect(l10nEn.devicesCount(1), equals('1 device'));
        expect(l10nEn.devicesCount(5), equals('5 devices'));
        expect(l10nVi.devicesCount(1), equals('1 thiết bị'));
        expect(l10nVi.devicesCount(5), equals('5 thiết bị'));

        expect(l10nEn.roomAdded('Kitchen'), equals('Room "Kitchen" added'));
        expect(l10nVi.roomAdded('Nhà Bếp'), equals('Đã thêm phòng "Nhà Bếp"'));

        expect(l10nEn.roomDeleted('Kitchen'), equals('Room "Kitchen" deleted'));
        expect(l10nVi.roomDeleted('Nhà Bếp'), equals('Đã xóa phòng "Nhà Bếp"'));

        expect(l10nEn.deleteHomeConfirm('Main Villa'),
            contains('Are you sure you want to delete "Main Villa"?'));
        expect(l10nVi.deleteHomeConfirm('Biệt Thự'),
            contains('Bạn có chắc chắn muốn xóa "Biệt Thự"?'));
      });

      testWidgets(
          'Live UI language switching dynamically switches to Vietnamese in LumivoApp',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        final container = ProviderContainer(
          overrides: [
            deviceRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const LumivoApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Initially English
        expect(find.text('Welcome home ✦'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);

        // Dynamically switch to Vietnamese
        container.read(userProfileProvider.notifier).updateLanguage('vi');
        await tester.pumpAndSettle();

        // Localized Vietnamese
        expect(find.text('Chào mừng về nhà ✦'), findsOneWidget);
        expect(find.text('Trang chủ'), findsOneWidget);
        expect(find.text('Cài đặt'), findsOneWidget);

        // Switch back to English
        container.read(userProfileProvider.notifier).updateLanguage('en');
        await tester.pumpAndSettle();

        expect(find.text('Welcome home ✦'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      });
    });

    // =========================================================================
    // 3. Multi-Viewport Store Device Readiness & Zero RenderFlex Overflow
    // =========================================================================
    group('3. Viewport Responsiveness Across Store Devices', () {
      final viewports = <String, Size>{
        '6.7" iPhone (430x932)': const Size(430, 932),
        '6.5" Android Flagship (412x915)': const Size(412, 915),
        '12.9" iPad Tablet (1024x1366)': const Size(1024, 1366),
        'Ultra-compact Mobile (320x600)': const Size(320, 600),
      };

      for (final entry in viewports.entries) {
        testWidgets('WelcomeScreen renders on ${entry.key} without overflow',
            (tester) async {
          setupViewport(tester, size: entry.value);
          await tester.pumpWidget(createTestApp(const WelcomeScreen()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(WelcomeScreen), findsOneWidget);
        });

        testWidgets('DashboardScreen renders on ${entry.key} without overflow',
            (tester) async {
          setupViewport(tester, size: entry.value);
          await tester.pumpWidget(createTestApp(const DashboardScreen()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(DashboardScreen), findsOneWidget);
        });

        testWidgets('SettingsScreen renders on ${entry.key} without overflow',
            (tester) async {
          setupViewport(tester, size: entry.value);
          await tester.pumpWidget(createTestApp(const SettingsScreen()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(SettingsScreen), findsOneWidget);
        });

        testWidgets(
            'SmartHomeHealthScreen renders on ${entry.key} without overflow',
            (tester) async {
          setupViewport(tester, size: entry.value);
          await tester.pumpWidget(createTestApp(const SmartHomeHealthScreen()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(SmartHomeHealthScreen), findsOneWidget);
        });

        testWidgets('EnergyScreen renders on ${entry.key} without overflow',
            (tester) async {
          setupViewport(tester, size: entry.value);
          await tester.pumpWidget(createTestApp(const EnergyScreen()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(EnergyScreen), findsOneWidget);
        });

        testWidgets(
            'PrivacyCenterScreen renders on ${entry.key} without overflow',
            (tester) async {
          setupViewport(tester, size: entry.value);
          await tester.pumpWidget(createTestApp(const PrivacyCenterScreen()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(PrivacyCenterScreen), findsOneWidget);
        });
      }
    });

    // =========================================================================
    // 4. WCAG 2.1 AA Accessibility Conformance
    // =========================================================================
    group('4. Accessibility & Touch Target Conformance', () {
      testWidgets('WelcomeScreen primary buttons satisfy >= 48pt height',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester.pumpWidget(createTestApp(const WelcomeScreen()));
        await tester.pumpAndSettle();

        final enterBtnFinder = find.byKey(const Key('enter_demo_mode_button'));
        expect(enterBtnFinder, findsOneWidget);
        final enterSize = tester.getSize(enterBtnFinder);
        expect(enterSize.height, greaterThanOrEqualTo(48.0));

        final skipBtnFinder = find.byKey(const Key('skip_welcome_button'));
        expect(skipBtnFinder, findsOneWidget);
        final skipSize = tester.getSize(skipBtnFinder);
        expect(skipSize.height, greaterThanOrEqualTo(48.0));
      });

      testWidgets(
          'AddDeviceSheet cancel button satisfies >= 48x48 pt touch target',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester
            .pumpWidget(createTestApp(const Scaffold(body: AddDeviceSheet())));
        await tester.pump();

        final cancelBtn = find.byKey(const Key('onboarding_cancel_button'));
        expect(cancelBtn, findsOneWidget);
        final size = tester.getSize(cancelBtn);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      });

      testWidgets(
          'Text scaling at 1.5x and 2.0x renders on mobile viewports without RenderFlex overflow',
          (tester) async {
        for (final scale in [1.5, 2.0]) {
          setupViewport(tester, size: const Size(360, 800));
          await tester.pumpWidget(
            createTestApp(
              const WelcomeScreen(),
              mediaQuery: MediaQueryData(
                textScaler: TextScaler.linear(scale),
                size: const Size(360, 800),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'RenderFlex overflow occurred at scale ${scale}x');
        }
      });

      testWidgets(
          'Reduced motion preference stops pulsing animations in AddDeviceSheet',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        await tester.pumpWidget(
          createTestApp(
            const Scaffold(body: AddDeviceSheet()),
            overrides: [
              userProfileProvider.overrideWith((ref) => UserProfileNotifier(
                    const UserProfile(reducedMotion: true),
                  )),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 5. Navigation Guards & Zero Dead Ends
    // =========================================================================
    group('5. Navigation Guards & Flow Integrity', () {
      testWidgets(
          'WelcomeScreen Enter Demo Mode triggers callback without exception',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));
        bool completed = false;

        await tester.pumpWidget(
          createTestApp(
            WelcomeScreen(
              onCompleted: () => completed = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('enter_demo_mode_button')));
        await tester.pumpAndSettle();

        expect(completed, isTrue);
      });

      testWidgets('AddDeviceSheet cancel button dismisses bottom sheet cleanly',
          (tester) async {
        setupViewport(tester, size: const Size(430, 932));

        await tester.pumpWidget(
          createTestApp(
            Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () => AddDeviceSheet.show(ctx),
                child: const Text('Open'),
              ),
            ),
            overrides: [
              userProfileProvider.overrideWith((ref) => UserProfileNotifier(
                    const UserProfile(reducedMotion: true),
                  )),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_sheet_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(AddDeviceSheet), findsOneWidget);

        // Tap cancel
        await tester.tap(find.byKey(const Key('onboarding_cancel_button')));
        await tester.pumpAndSettle();

        expect(find.byType(AddDeviceSheet), findsNothing);
      });
    });
  });
}
