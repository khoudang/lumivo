import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/core/theme/app_theme.dart';
import 'package:lumivo/features/dashboard/widgets/brightness_slider_card.dart';
import 'package:lumivo/features/dashboard/widgets/device_card.dart';
import 'package:lumivo/features/dashboard/widgets/metric_card.dart';
import 'package:lumivo/features/dashboard/widgets/room_selector.dart';
import 'package:lumivo/features/onboarding/presentation/add_device_sheet.dart';

void main() {
  group('UI Components Test Suite', () {
    testWidgets('DeviceCard renders and triggers toggle', (tester) async {
      bool toggled = false;
      const device = SmartDevice(
        id: 'test-light',
        name: 'Desk Lamp',
        roomId: 'Living Room',
        type: DeviceType.light,
        isOn: true,
        brightness: 75,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      expect(find.text('Desk Lamp'), findsOneWidget);
      expect(find.text('75% · Living Room'), findsOneWidget);

      await tester.tap(find.byType(DeviceCard));
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('DeviceCard renders offline state', (tester) async {
      const offlineDevice = SmartDevice(
        id: 'test-offline',
        name: 'Outdoor Sensor',
        roomId: 'Garden',
        type: DeviceType.security,
        isOn: false,
        connection: DeviceConnection.offline,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: DeviceCard(device: offlineDevice),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Disconnected · Garden'), findsOneWidget);
    });

    testWidgets('BrightnessSliderCard renders readout and presets',
        (tester) async {
      double currentVal = 50.0;
      const light = SmartDevice(
        id: 'test-light-2',
        name: 'Ceiling Light',
        roomId: 'Kitchen',
        type: DeviceType.light,
        isOn: true,
        brightness: 50,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BrightnessSliderCard(
                  device: light,
                  brightness: currentVal,
                  onChanged: (val) => setState(() => currentVal = val),
                  onChangeEnd: (val) => setState(() => currentVal = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Ceiling Light Brightness'), findsOneWidget);
      expect(find.text('50%'), findsNWidgets(2)); // Readout + Preset chip

      // Tap preset 100%
      await tester.tap(find.text('100%'));
      await tester.pump();
      expect(currentVal, equals(100.0));
    });

    testWidgets('RoomSelector renders rooms and count badges', (tester) async {
      String selected = 'Living Room';
      final counts = {'Living Room': 3, 'Bedroom': 2, 'Kitchen': 1};

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RoomSelector(
                  rooms: const ['Living Room', 'Bedroom', 'Kitchen'],
                  selectedRoom: selected,
                  onRoomSelected: (r) => setState(() => selected = r),
                  roomDeviceCounts: counts,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Bedroom'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('Bedroom'));
      await tester.pump();
      expect(selected, equals('Bedroom'));
    });

    testWidgets('MetricCard displays value, label and status badge',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: MetricCard(
              icon: Icons.thermostat_rounded,
              tint: AppColors.warning,
              value: '24.2°C',
              label: 'Indoor Temp',
              statusBadge: 'Ideal',
            ),
          ),
        ),
      );

      expect(find.text('24.2°C'), findsOneWidget);
      expect(find.text('Indoor Temp'), findsOneWidget);
      expect(find.text('Ideal'), findsOneWidget);
    });

    testWidgets('AddDeviceSheet shows scanning and discovers devices',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddDeviceSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Discovered Devices'), findsOneWidget);
      expect(find.text('Scanning for nearby BLE devices...'), findsOneWidget);
      expect(find.text('Lumivo Ambient Aura'), findsOneWidget);

      // Select first device
      await tester.tap(find.text('Connect').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Wi-Fi Setup'), findsOneWidget);
      expect(find.text('Wi-Fi Network (SSID)'), findsOneWidget);
    });
  });
}
