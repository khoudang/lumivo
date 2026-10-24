import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/device_detail/presentation/device_detail_screen.dart';
import 'package:lumivo/features/onboarding/presentation/splash_screen.dart';
import 'package:lumivo/features/onboarding/presentation/welcome_screen.dart';
import 'package:lumivo/features/settings/presentation/settings_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('Phase 4 Mobile UI/UX & First-Run Suite', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
    });

    tearDown(() async {
      await repository.dispose();
    });

    Widget createTestApp(
      Widget child, {
      List<Override> overrides = const [],
    }) {
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

    void setupViewport(WidgetTester tester,
        {Size size = const Size(800, 1400)}) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // -------------------------------------------------------------
    // 1. FirstRunNotifier Unit Tests
    // -------------------------------------------------------------
    group('FirstRunNotifier Unit Tests', () {
      test('initializes with default false when storage empty', () async {
        final stubStorage = StorageAdapterImpl();
        final notifier = FirstRunNotifier(storage: stubStorage);

        expect(notifier.state, isFalse);
      });

      test('completeFirstRun() sets state to true and persists to storage',
          () async {
        final stubStorage = StorageAdapterImpl();
        final notifier = FirstRunNotifier(storage: stubStorage);

        await notifier.completeFirstRun();

        expect(notifier.state, isTrue);
        final persisted =
            await stubStorage.getString(FirstRunNotifier.storageKey);
        expect(persisted, 'true');
      });

      test('resetFirstRun() reverts state to false and persists', () async {
        final stubStorage = StorageAdapterImpl();
        final notifier = FirstRunNotifier(
          initialValue: true,
          storage: stubStorage,
        );

        await notifier.resetFirstRun();

        expect(notifier.state, isFalse);
        final persisted =
            await stubStorage.getString(FirstRunNotifier.storageKey);
        expect(persisted, 'false');
      });

      test('loads existing true status from persistent storage', () async {
        final stubStorage = StorageAdapterImpl();
        await stubStorage.setString(FirstRunNotifier.storageKey, 'true');

        final notifier = FirstRunNotifier(storage: stubStorage);
        // Wait for async load to finish
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(notifier.state, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 2. WelcomeScreen Widget Tests
    // -------------------------------------------------------------
    group('WelcomeScreen Widget Tests', () {
      testWidgets('renders distinct Lumivo branding and tagline',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(const WelcomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('LUMIVO Smart Home'), findsOneWidget);
        expect(find.text('Intelligent Living, Beautifully Simple'),
            findsOneWidget);
        expect(find.byIcon(Icons.blur_on_rounded), findsOneWidget);
      });

      testWidgets('renders prominent offline demo mode callout badge',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(const WelcomeScreen()));
        await tester.pumpAndSettle();

        expect(
          find.text(
            '✦ DEMO MODE • 100% OFFLINE SMART HOME — No hardware, cloud login, or external network required.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders swipeable feature highlights and indicator dots',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(const WelcomeScreen()));
        await tester.pumpAndSettle();

        // Initial page (Deterministic IoT Simulation)
        expect(find.text('Deterministic IoT Simulation'), findsOneWidget);
        expect(
          find.text(
            'Bulbs, fans, climate AC, sockets, curtains, smart locks & environment sensors.',
          ),
          findsOneWidget,
        );

        // Tap page indicator 1
        await tester.tap(find.byKey(const Key('welcome_indicator_1')));
        await tester.pumpAndSettle();

        expect(find.text('Ambiance & Automated Routines'), findsOneWidget);
        expect(
          find.text(
            'One-tap scenes, schedule-based triggers & threshold sensor automations.',
          ),
          findsOneWidget,
        );

        // Tap page indicator 2
        await tester.tap(find.byKey(const Key('welcome_indicator_2')));
        await tester.pumpAndSettle();

        expect(find.text('Simulated Energy Telemetry'), findsOneWidget);
        expect(
          find.text(
            'Live wattage consumption, historical telemetry & configurable tariffs.',
          ),
          findsOneWidget,
        );
      });

      testWidgets(
          'tapping "Enter Demo Mode" completes first-run status and calls onCompleted',
          (WidgetTester tester) async {
        setupViewport(tester);
        bool completedInvoked = false;

        final stubStorage = StorageAdapterImpl();
        final notifier = FirstRunNotifier(storage: stubStorage);

        await tester.pumpWidget(
          createTestApp(
            WelcomeScreen(onCompleted: () => completedInvoked = true),
            overrides: [
              firstRunCompletedProvider.overrideWith((ref) => notifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final enterButton = find.byKey(const Key('enter_demo_mode_button'));
        expect(enterButton, findsOneWidget);

        await tester.tap(enterButton);
        await tester.pumpAndSettle();

        expect(completedInvoked, isTrue);
        expect(notifier.state, isTrue);
      });

      testWidgets('tapping "Skip to Dashboard" triggers completion',
          (WidgetTester tester) async {
        setupViewport(tester);
        bool completedInvoked = false;

        final stubStorage = StorageAdapterImpl();
        final notifier = FirstRunNotifier(storage: stubStorage);

        await tester.pumpWidget(
          createTestApp(
            WelcomeScreen(onCompleted: () => completedInvoked = true),
            overrides: [
              firstRunCompletedProvider.overrideWith((ref) => notifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final skipButton = find.byKey(const Key('skip_welcome_button'));
        expect(skipButton, findsOneWidget);

        await tester.tap(skipButton);
        await tester.pumpAndSettle();

        expect(completedInvoked, isTrue);
        expect(notifier.state, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 3. SplashScreen Presentation & Animation Tests
    // -------------------------------------------------------------
    group('SplashScreen Presentation Tests', () {
      testWidgets('renders glowing emblem, title and tagline',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(const SplashScreen()));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byKey(const Key('splash_screen_emblem')), findsOneWidget);
        expect(find.text('LUMIVO'), findsOneWidget);
        expect(find.text('Intelligent Living, Beautifully Simple'),
            findsOneWidget);
      });

      testWidgets('triggers onComplete callback when duration elapses',
          (WidgetTester tester) async {
        setupViewport(tester);
        bool finished = false;

        await tester.pumpWidget(
          createTestApp(
            SplashScreen(
              duration: const Duration(milliseconds: 300),
              onComplete: () => finished = true,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 150));
        expect(finished, isFalse);

        await tester.pump(const Duration(milliseconds: 200));
        expect(finished, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 4. Settings Screen Welcome & Demo Tour Tile
    // -------------------------------------------------------------
    group('Settings Screen Welcome Tour Integration', () {
      testWidgets('renders Welcome & Demo Tour tile and opens WelcomeScreen',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();

        final tourTile = find.byKey(const Key('open_welcome_tour_tile'));
        expect(tourTile, findsOneWidget);
        expect(find.text('Welcome & Demo Tour'), findsOneWidget);

        // Tap tour tile opens WelcomeScreen
        await tester.tap(tourTile);
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.text('LUMIVO Smart Home'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------
    // 5. Touch Target Sizes Verification (>= 44-48 pt)
    // -------------------------------------------------------------
    group('Touch Target Polish Tests (minimum 44-48 pt)', () {
      testWidgets('key dashboard interactive elements meet touch target bounds',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        // Add Device FAB
        final fabSize =
            tester.getSize(find.byKey(const Key('dashboard_add_device_fab')));
        expect(fabSize.width, greaterThanOrEqualTo(48.0));
        expect(fabSize.height, greaterThanOrEqualTo(48.0));

        // Notifications button
        final notifSize = tester.getSize(
          find.byKey(const Key('dashboard_notifications_button')),
        );
        expect(notifSize.width, greaterThanOrEqualTo(44.0));
        expect(notifSize.height, greaterThanOrEqualTo(44.0));

        // Profile button
        final profileSize = tester.getSize(
          find.byKey(const Key('dashboard_profile_button')),
        );
        expect(profileSize.width, greaterThanOrEqualTo(44.0));
        expect(profileSize.height, greaterThanOrEqualTo(44.0));

        // Device card power toggle
        final powerToggles = find.byIcon(Icons.toggle_on_rounded);
        expect(powerToggles, findsWidgets);
        final toggleSize = tester.getSize(powerToggles.first);
        expect(toggleSize.width, greaterThanOrEqualTo(30.0));
      });

      testWidgets(
          'device detail sliders and chips have comfortable touch height',
          (WidgetTester tester) async {
        setupViewport(tester);

        const sampleLight = SmartDevice(
          id: 'test-light-1',
          name: 'Living Room Light',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          brightness: 75,
        );

        await tester.pumpWidget(
          createTestApp(const DeviceDetailScreen(device: sampleLight)),
        );
        await tester.pumpAndSettle();

        // Brightness slider has comfortable height (>= 44 pt)
        final slider = find.byType(Slider);
        expect(slider, findsOneWidget);
        final sliderSize = tester.getSize(slider);
        expect(sliderSize.height, greaterThanOrEqualTo(44.0));

        // Favorite star button
        final favButton =
            find.byKey(const Key('device_detail_favorite_button'));
        final favSize = tester.getSize(favButton);
        expect(favSize.width, greaterThanOrEqualTo(44.0));
        expect(favSize.height, greaterThanOrEqualTo(44.0));
      });
    });

    // -------------------------------------------------------------
    // 6. Responsive Small Mobile Viewport (320x600) - Zero Overflows
    // -------------------------------------------------------------
    group('Narrow Screen Responsiveness (320x600 Viewport)', () {
      testWidgets(
          'DashboardScreen renders on 320x600 without RenderFlex overflow',
          (WidgetTester tester) async {
        setupViewport(tester, size: const Size(320, 600));

        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtError = details;
        };

        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        FlutterError.onError = oldHandler;
        if (caughtError != null) {
          throw TestFailure('FULL ERROR: ${caughtError!.toString()}');
        }
        expect(find.text('LUMIVO'), findsOneWidget);
        expect(find.text('Welcome home ✦'), findsOneWidget);
      });

      testWidgets(
          'WelcomeScreen renders on 320x600 without RenderFlex overflow',
          (WidgetTester tester) async {
        setupViewport(tester, size: const Size(320, 600));

        await tester.pumpWidget(createTestApp(const WelcomeScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('LUMIVO Smart Home'), findsOneWidget);
        expect(find.byKey(const Key('enter_demo_mode_button')), findsOneWidget);
      });

      testWidgets('SplashScreen renders on 320x600 without RenderFlex overflow',
          (WidgetTester tester) async {
        setupViewport(tester, size: const Size(320, 600));

        await tester.pumpWidget(createTestApp(const SplashScreen()));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('LUMIVO'), findsOneWidget);
      });

      testWidgets(
          'DeviceDetailScreen renders on 320x600 without RenderFlex overflow',
          (WidgetTester tester) async {
        setupViewport(tester, size: const Size(320, 600));

        const sampleAc = SmartDevice(
          id: 'test-ac-1',
          name: 'Master Bedroom AC',
          roomId: 'Bedroom',
          type: DeviceType.ac,
          isOn: true,
          targetTemperature: 23.0,
          currentTemperature: 25.5,
        );

        await tester.pumpWidget(
          createTestApp(const DeviceDetailScreen(device: sampleAc)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Master Bedroom AC'), findsWidgets);
      });
    });
  });
}
