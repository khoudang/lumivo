import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/features/automation/presentation/automation_history_sheet.dart';
import 'package:lumivo/features/automation/presentation/automation_screen.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/features/health/presentation/smart_home_health_screen.dart';
import 'package:lumivo/features/lab/presentation/demo_lab_sheet.dart';
import 'package:lumivo/features/onboarding/presentation/add_device_sheet.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 5 Consumer UI/UX Comprehensive Test Suite', () {
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
            id: 'lock-1',
            name: 'Front Door Lock',
            roomId: 'Living Room',
            type: DeviceType.lock,
            isOn: true,
            connection: DeviceConnection.online,
          ),
          SmartDevice(
            id: 'security-1',
            name: 'Perimeter Sensor',
            roomId: 'Living Room',
            type: DeviceType.security,
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

    void setupViewport(WidgetTester tester,
        {Size size = const Size(800, 1200)}) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // -------------------------------------------------------------
    // 1. Add Device Onboarding Tests
    // -------------------------------------------------------------
    group('Add Device Onboarding (Radar, Pairing, Retry & Cancel)', () {
      testWidgets(
          'Scanning view renders pulsating radar and discovered devices count',
          (tester) async {
        setupViewport(tester);
        await tester
            .pumpWidget(createTestApp(const Scaffold(body: AddDeviceSheet())));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Discovered Devices'), findsOneWidget);
        expect(find.text('Scanning for nearby BLE devices...'), findsOneWidget);
        expect(find.text('3 devices found'), findsOneWidget);
        expect(find.text('Lumivo Ambient Aura'), findsOneWidget);
        expect(
            find.byKey(const Key('onboarding_cancel_button')), findsOneWidget);
      });

      testWidgets('BLE connect advances to Wi-Fi setup with cancel button',
          (tester) async {
        setupViewport(tester);
        await tester
            .pumpWidget(createTestApp(const Scaffold(body: AddDeviceSheet())));
        await tester.pump(const Duration(milliseconds: 200));

        // Connect first device
        await tester.tap(find.text('Connect').first);
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Wi-Fi Setup'), findsOneWidget);
        expect(find.text('Wi-Fi Network (SSID)'), findsOneWidget);
        expect(find.text('Provision & Connect Device'), findsOneWidget);
        expect(
            find.byKey(const Key('onboarding_cancel_button')), findsOneWidget);
      });

      testWidgets(
          'Timeout flow renders retry and cancel buttons, retry recovers to success',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(
          createTestApp(
            const Scaffold(
              body: AddDeviceSheet(simulateTimeout: true),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Tap Connect to start pairing with simulated timeout
        await tester.tap(find.text('Connect').first);
        await tester.pump(const Duration(milliseconds: 350));

        // Tap Provision & Connect
        await tester.tap(find.text('Provision & Connect Device'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Should transition to Timeout state
        expect(
            find.byKey(const Key('onboarding_retry_button')), findsOneWidget);
        expect(
            find.byKey(const Key('onboarding_cancel_button')), findsOneWidget);
        expect(find.text('Pairing timed out'), findsAtLeastNWidgets(1));

        // Tap retry button
        await tester.tap(find.byKey(const Key('onboarding_retry_button')));
        await tester.pump();
        // Advance timer through provisioning steps to completion
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 500));

        // Verifies Room Assignment Dropdown rendered on success view
        expect(find.text('Device Ready!'), findsOneWidget);
        expect(
            find.byKey(const Key('room_assignment_dropdown')), findsOneWidget);
      });

      testWidgets('Cancel button pops modal sheet', (tester) async {
        setupViewport(tester);
        bool popped = false;

        await tester.pumpWidget(
          createTestApp(
            Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => const AddDeviceSheet(),
                    ).then((_) => popped = true);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(AddDeviceSheet), findsOneWidget);
        await tester.tap(find.byKey(const Key('onboarding_cancel_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(popped, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 2. Smart Home Health Dashboard Tests
    // -------------------------------------------------------------
    group('Smart Home Health Dashboard', () {
      testWidgets(
          'Renders health score dial, count cards, warnings and device items',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const SmartHomeHealthScreen()));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('smart_home_health_screen')), findsOneWidget);
        expect(find.text('Smart Home Health'), findsOneWidget);
        expect(find.text('System Health Score'), findsOneWidget);

        // Score percentage rendered
        expect(find.textContaining('%'), findsAtLeastNWidgets(1));

        // Count cards
        expect(find.text('Online Devices'), findsOneWidget);
        expect(find.text('Offline Devices'), findsOneWidget);
        expect(find.textContaining('Degraded'), findsAtLeastNWidgets(1));

        // Warning section
        expect(find.text('Active Warnings'), findsOneWidget);
        expect(find.textContaining('Perimeter Sensor (Living Room): Offline'),
            findsOneWidget);

        // Reconnect button for offline device
        await tester.ensureVisible(
          find.byKey(const Key('reconnect_device_security-1')),
        );
        expect(find.byKey(const Key('reconnect_device_security-1')),
            findsOneWidget);
      });

      testWidgets('Tapping reconnect button restores device online',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const SmartHomeHealthScreen()));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('reconnect_device_security-1')),
        );
        await tester.pumpAndSettle();

        // Tap reconnect on offline security device
        await tester.tap(find.byKey(const Key('reconnect_device_security-1')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Security device should now be online in repository
        final devices = repository.devices;
        final sec = devices.firstWhere((d) => d.id == 'security-1');
        expect(sec.connection, equals(DeviceConnection.online));
      });
    });

    // -------------------------------------------------------------
    // 3. Automation Management Polish Tests
    // -------------------------------------------------------------
    group('Automation Management Polish (Duplicate, History & Badges)', () {
      testWidgets(
          'Renders execution history button and duplicate button on rules',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const AutomationScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('view_automation_history_button')),
            findsOneWidget);

        // Duplicate button exists for default rule
        expect(find.byKey(const Key('duplicate_automation_rule-temp-trigger')),
            findsOneWidget);
      });

      testWidgets('Tapping duplicate rule confirms and clones automation rule',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const AutomationScreen()));
        await tester.pumpAndSettle();

        // Tap duplicate button on rule-temp-trigger
        await tester.tap(
            find.byKey(const Key('duplicate_automation_rule-temp-trigger')));
        await tester.pumpAndSettle();

        // Dialog should be visible
        expect(find.text('Create a duplicate copy of "Auto Cool Living Room"?'),
            findsOneWidget);

        // Confirm duplication
        await tester
            .tap(find.byKey(const Key('confirm_duplicate_rule-temp-trigger')));
        await tester.pumpAndSettle();

        // Cloned rule should appear in list
        expect(find.text('Auto Cool Living Room (Copy)'), findsOneWidget);
      });

      testWidgets(
          'Tapping history button opens AutomationHistorySheet with status badges',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const AutomationScreen()));
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const Key('view_automation_history_button')));
        await tester.pumpAndSettle();

        expect(find.byType(AutomationHistorySheet), findsOneWidget);
        expect(find.text('Execution History'), findsOneWidget);
        expect(find.text('Executed'), findsAtLeastNWidgets(1));
        expect(find.text('Skipped'), findsAtLeastNWidgets(1));
        expect(find.text('Loop Prevented'), findsAtLeastNWidgets(1));
        expect(find.text('Failed'), findsAtLeastNWidgets(1));
      });
    });

    // -------------------------------------------------------------
    // 4. Demo Lab Fault Injection UI Tests
    // -------------------------------------------------------------
    group('Demo Lab Fault Injection UI', () {
      testWidgets(
          'Renders force offline button, packet loss slider and storm button',
          (tester) async {
        setupViewport(tester);
        await tester
            .pumpWidget(createTestApp(const Scaffold(body: DemoLabSheet())));
        await tester.pumpAndSettle();

        expect(find.text('Demo Lab & Fault Injection'), findsOneWidget);
        expect(find.byKey(const Key('fault_force_offline_button')),
            findsOneWidget);
        expect(
            find.byKey(const Key('fault_packet_loss_slider')), findsOneWidget);
        expect(find.byKey(const Key('fault_reconnect_storm_button')),
            findsOneWidget);
      });

      testWidgets('Force offline button toggles device connection state',
          (tester) async {
        setupViewport(tester);
        await tester
            .pumpWidget(createTestApp(const Scaffold(body: DemoLabSheet())));
        await tester.pumpAndSettle();

        // First device is light-1 (online)
        await tester.tap(find.byKey(const Key('fault_force_offline_button')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final dev = repository.devices.firstWhere((d) => d.id == 'light-1');
        expect(dev.connection, equals(DeviceConnection.offline));
      });

      testWidgets('Reconnect storm button executes without error',
          (tester) async {
        setupViewport(tester);
        await tester
            .pumpWidget(createTestApp(const Scaffold(body: DemoLabSheet())));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fault_reconnect_storm_button')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.textContaining('Reconnect Storm'), findsAtLeastNWidgets(1));
      });
    });

    // -------------------------------------------------------------
    // 5. Dashboard Integration Tests
    // -------------------------------------------------------------
    group('Dashboard Integration Buttons', () {
      testWidgets('Dashboard renders Smart Home Health and Demo Lab buttons',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('dashboard_health_button')), findsOneWidget);
        expect(
            find.byKey(const Key('dashboard_demo_lab_button')), findsOneWidget);
      });

      testWidgets(
          'Tapping dashboard_health_button navigates to SmartHomeHealthScreen',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_health_button')));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('smart_home_health_screen')), findsOneWidget);
      });

      testWidgets('Tapping dashboard_demo_lab_button opens DemoLabSheet',
          (tester) async {
        setupViewport(tester);
        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_demo_lab_button')));
        await tester.pumpAndSettle();

        expect(find.byType(DemoLabSheet), findsOneWidget);
      });
    });

    // -------------------------------------------------------------
    // 6. Responsive Small Mobile Viewport (320x600) - Zero Overflows
    // -------------------------------------------------------------
    group('Narrow Screen Responsiveness (320x600 Viewport)', () {
      testWidgets(
          'DashboardScreen renders on 320x600 without RenderFlex overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));

        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) => caughtError = details;

        await tester.pumpWidget(createTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();

        FlutterError.onError = oldHandler;
        if (caughtError != null) {
          throw TestFailure('FULL ERROR: ${caughtError!.toString()}');
        }
        expect(
            find.byKey(const Key('dashboard_health_button')), findsOneWidget);
      });

      testWidgets(
          'SmartHomeHealthScreen renders on 320x600 without RenderFlex overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));

        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) => caughtError = details;

        await tester.pumpWidget(createTestApp(const SmartHomeHealthScreen()));
        await tester.pumpAndSettle();

        FlutterError.onError = oldHandler;
        if (caughtError != null) {
          throw TestFailure('FULL ERROR: ${caughtError!.toString()}');
        }
        expect(
            find.byKey(const Key('smart_home_health_screen')), findsOneWidget);
      });

      testWidgets(
          'AddDeviceSheet renders on 320x600 without RenderFlex overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));

        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) => caughtError = details;

        await tester
            .pumpWidget(createTestApp(const Scaffold(body: AddDeviceSheet())));
        await tester.pump(const Duration(milliseconds: 250));

        FlutterError.onError = oldHandler;
        if (caughtError != null) {
          throw TestFailure('FULL ERROR: ${caughtError!.toString()}');
        }
        expect(
            find.byKey(const Key('onboarding_cancel_button')), findsOneWidget);
      });

      testWidgets('DemoLabSheet renders on 320x600 without RenderFlex overflow',
          (tester) async {
        setupViewport(tester, size: const Size(320, 600));

        FlutterErrorDetails? caughtError;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) => caughtError = details;

        await tester
            .pumpWidget(createTestApp(const Scaffold(body: DemoLabSheet())));
        await tester.pumpAndSettle();

        FlutterError.onError = oldHandler;
        if (caughtError != null) {
          throw TestFailure('FULL ERROR: ${caughtError!.toString()}');
        }
        expect(find.byKey(const Key('fault_force_offline_button')),
            findsOneWidget);
      });
    });
  });
}
