import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/theme/app_theme.dart';
import 'package:lumivo/features/automation/presentation/automation_screen.dart';
import 'package:lumivo/features/demo_lab/presentation/demo_lab_screen.dart';
import 'package:lumivo/features/device_detail/presentation/device_detail_screen.dart';
import 'package:lumivo/features/rooms/presentation/rooms_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('Phase 2 UI Screens Comprehensive Test Suite', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
    });

    tearDown(() async {
      await repository.dispose();
    });

    Widget createTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: child),
        ),
      );
    }

    void setupViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    // ==========================================
    // 1. RoomsScreen Tests
    // ==========================================
    group('RoomsScreen', () {
      testWidgets('renders all default rooms, counts and adds a new room',
          (WidgetTester tester) async {
        setupViewport(tester);
        String? selectedRoom;

        await tester.pumpWidget(
          createTestApp(
            RoomsScreen(
              onRoomSelected: (r) => selectedRoom = r,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header
        expect(find.text('ROOMS'), findsOneWidget);
        expect(find.text('Spaces & Zones'), findsOneWidget);

        // Default rooms
        expect(find.text('Living Room'), findsOneWidget);
        expect(find.text('Bedroom'), findsOneWidget);
        expect(find.text('Kitchen'), findsOneWidget);
        expect(find.text('Office'), findsOneWidget);
        expect(find.text('Bathroom'), findsOneWidget);
        expect(find.text('Balcony'), findsOneWidget);

        // Tap room card invokes onRoomSelected
        await tester.tap(find.text('Living Room'));
        await tester.pumpAndSettle();
        expect(selectedRoom, equals('Living Room'));

        // Tap "+ Add Room" button
        await tester.tap(find.byKey(const Key('add_room_button')));
        await tester.pumpAndSettle();

        expect(find.text('Add New Room'), findsOneWidget);
        expect(find.text('Room Name'), findsOneWidget);

        // Enter new room name
        await tester.enterText(find.byType(TextField).first, 'Game Room');
        await tester.pump();

        // Select Office icon
        await tester.tap(find.text('Office').last);
        await tester.pump();

        // Tap Add Room action
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Room').last);
        await tester.pumpAndSettle();

        // Verify new room added
        expect(find.text('Game Room'), findsOneWidget);
      });
    });

    // ==========================================
    // 2. DeviceDetailScreen Tests
    // ==========================================
    group('DeviceDetailScreen Specialized Controls', () {
      // 2a. Light / Bulb
      testWidgets(
          'Light / Bulb: renders brightness slider, moods and power toggle',
          (WidgetTester tester) async {
        setupViewport(tester);
        const lightDevice = SmartDevice(
          id: 'custom-light-1',
          name: 'Living Room Chandelier',
          roomId: 'Living Room',
          type: DeviceType.light,
          isOn: true,
          brightness: 75,
        );

        await tester.pumpWidget(createTestApp(
          const DeviceDetailScreen(device: lightDevice),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Living Room Chandelier'), findsWidgets);
        expect(find.text('Light Controls'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
        expect(find.text('Warm 2700K'), findsOneWidget);
        expect(find.text('Cool 6500K'), findsOneWidget);

        // Select color mood
        await tester.tap(find.text('Cool 6500K'));
        await tester.pumpAndSettle();

        // Toggle power switch
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
      });

      // 2b. AC / Climate
      testWidgets('AC: renders target temperature stepper and mode selector',
          (WidgetTester tester) async {
        setupViewport(tester);
        const acDevice = SmartDevice(
          id: 'ac-1',
          name: 'Living Room AC',
          roomId: 'Living Room',
          type: DeviceType.ac,
          isOn: true,
          targetTemperature: 24.0,
          currentTemperature: 26.5,
        );

        await tester.pumpWidget(createTestApp(
          const DeviceDetailScreen(device: acDevice),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Climate Control'), findsOneWidget);
        expect(find.text('24.0°C'), findsOneWidget);
        expect(find.text('Current: 26.5°C'), findsOneWidget);
        expect(find.text('Cool'), findsOneWidget);
        expect(find.text('Eco'), findsOneWidget);

        // Increase temp by tapping plus stepper
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(find.text('24.5°C'), findsOneWidget);

        // Select Eco mode
        await tester.tap(find.text('Eco'));
        await tester.pumpAndSettle();
      });

      // 2c. Smart Lock
      testWidgets('Smart Lock: renders prominent lock toggle and badge',
          (WidgetTester tester) async {
        setupViewport(tester);
        const lockDevice = SmartDevice(
          id: 'lock-1',
          name: 'Front Door Lock',
          roomId: 'Living Room',
          type: DeviceType.lock,
          isOn: true,
          isLocked: true,
        );

        await tester.pumpWidget(createTestApp(
          const DeviceDetailScreen(device: lockDevice),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Smart Lock Security'), findsOneWidget);
        expect(find.text('Locked & Secured'), findsOneWidget);

        // Tap lock button to unlock
        await tester.tap(find.byIcon(Icons.lock_rounded).last);
        await tester.pumpAndSettle();

        expect(find.text('Unlocked'), findsOneWidget);
      });

      // 2d. Socket / Outlet
      testWidgets('Socket: renders wattage, today energy gauge and switch',
          (WidgetTester tester) async {
        setupViewport(tester);
        const socketDevice = SmartDevice(
          id: 'socket-1',
          name: 'Coffee Machine Plug',
          roomId: 'Kitchen',
          type: DeviceType.socket,
          isOn: true,
          powerUsageWatts: 145.0,
        );

        await tester.pumpWidget(createTestApp(
          const DeviceDetailScreen(device: socketDevice),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Power & Energy'), findsOneWidget);
        expect(find.text('145.0 W'), findsOneWidget);
        expect(find.text('1.85 kWh'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Toggle power
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
      });

      // 2e. Fan
      testWidgets('Fan: renders speed selector chips and power switch',
          (WidgetTester tester) async {
        setupViewport(tester);
        const fanDevice = SmartDevice(
          id: 'fan-1',
          name: 'Living Room Fan',
          roomId: 'Living Room',
          type: DeviceType.fan,
          isOn: true,
        );

        await tester.pumpWidget(createTestApp(
          const DeviceDetailScreen(device: fanDevice),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Fan Speed Control'), findsOneWidget);
        expect(find.text('Low'), findsOneWidget);
        expect(find.text('Medium'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);

        // Tap High speed
        await tester.tap(find.text('High'));
        await tester.pumpAndSettle();
      });

      // 2f. Curtain
      testWidgets('Curtain: renders position slider and quick actions',
          (WidgetTester tester) async {
        setupViewport(tester);
        const curtainDevice = SmartDevice(
          id: 'curtain-1',
          name: 'Balcony Curtain',
          roomId: 'Balcony',
          type: DeviceType.curtain,
          isOn: true,
          position: 50,
        );

        await tester.pumpWidget(createTestApp(
          const DeviceDetailScreen(device: curtainDevice),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Curtain Position'), findsOneWidget);
        expect(find.text('50% Open'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Stop'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);

        // Tap Open button
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('100% Open'), findsOneWidget);
      });

      // 2g. Sensor
      testWidgets('Sensor: renders gauges, battery and comfort rating',
          (WidgetTester tester) async {
        setupViewport(tester);
        const sensorDevice = SmartDevice(
          id: 'sensor-1',
          name: 'Balcony Multi-Sensor',
          roomId: 'Balcony',
          type: DeviceType.sensor,
          isOn: true,
          currentTemperature: 28.5,
          currentHumidity: 60.0,
        );

        await tester.pumpWidget(createTestApp(
          const DeviceDetailScreen(device: sensorDevice),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Environment Readout'), findsOneWidget);
        expect(find.text('28.5°C'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);
        expect(find.text('88%'), findsOneWidget);
        expect(find.text('Comfort Rating: Optimal (Normal air index)'),
            findsOneWidget);
      });
    });

    // ==========================================
    // 3. AutomationScreen Tests
    // ==========================================
    group('AutomationScreen', () {
      testWidgets(
          'renders automations & scenes tabs, toggles rule and runs scene',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(
          const AutomationScreen(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('ROUTINES & LOGIC'), findsOneWidget);
        expect(find.text('Automation'), findsOneWidget);

        // Default rules
        expect(find.text('Morning Routine'), findsOneWidget);
        expect(find.text('Auto Cool Living Room'), findsOneWidget);

        // Toggle first rule switch
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        // Switch to Scenes tab
        await tester.tap(find.text('Scenes'));
        await tester.pumpAndSettle();

        expect(find.text('Good Morning'), findsOneWidget);
        expect(find.text('Away'), findsOneWidget);
        expect(find.text('Night'), findsOneWidget);
        expect(find.text('Movie Time'), findsOneWidget);

        // Run "Good Morning" scene
        await tester.tap(find.byKey(const Key('run_scene_scene-1')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Scene "Good Morning" executed successfully!'),
            findsOneWidget);
      });
    });

    // ==========================================
    // 4. DemoLabScreen Tests
    // ==========================================
    group('DemoLabScreen', () {
      testWidgets('renders virtual clock, ambient controls and chaos toggles',
          (WidgetTester tester) async {
        setupViewport(tester);

        await tester.pumpWidget(createTestApp(
          const DemoLabScreen(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Demo Lab & Chaos Sim'), findsOneWidget);
        expect(find.text('Virtual Simulation Clock'), findsOneWidget);
        expect(find.text('Ambient Environment Controls'), findsOneWidget);
        expect(find.text('Chaos & Fault Injection'), findsOneWidget);

        // Speed multiplier button tap
        await tester.tap(find.byKey(const Key('speed_60x')));
        await tester.pumpAndSettle();
        expect(find.text('60x Speed'), findsOneWidget);

        // Advance 1 hour
        await tester.tap(find.byKey(const Key('advance_1_hour_button')));
        await tester.pumpAndSettle();
        expect(find.text('09:30 AM'), findsOneWidget);

        // Jump to 07:00
        await tester.tap(find.byKey(const Key('jump_0700_button')));
        await tester.pumpAndSettle();
        expect(find.text('07:00 AM'), findsOneWidget);

        // Toggle MQTT drop
        expect(find.text('MQTT Network Connected'), findsOneWidget);
        await tester.tap(find.byKey(const Key('toggle_mqtt_button')));
        await tester.pumpAndSettle();
        expect(find.text('MQTT Network Dropped'), findsOneWidget);
      });
    });
  });
}
