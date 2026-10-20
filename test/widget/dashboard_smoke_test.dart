import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';

void main() {
  group('DashboardScreen Widget Smoke Tests', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
    });

    tearDown(() async {
      await repository.dispose();
    });

    Widget createDashboardWidget() {
      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
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

    testWidgets('dashboard renders initial devices in Living Room',
        (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      expect(find.text('LUMIVO'), findsOneWidget);
      expect(find.text('Welcome home ✦'), findsOneWidget);
      expect(find.text('3 devices'), findsOneWidget);

      expect(find.text('Smart Light'), findsOneWidget);
      expect(find.text('Smart Fan'), findsOneWidget);
      expect(find.text('Home Security'), findsOneWidget);

      expect(find.text('Bedside Light'), findsNothing);
      expect(find.text('Kitchen Light'), findsNothing);
    });

    testWidgets('room filtering shows correct subset of devices',
        (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      expect(find.text('Smart Light'), findsOneWidget);

      await tester.tap(find.text('Bedroom'));
      await tester.pumpAndSettle();

      expect(find.text('2 devices'), findsOneWidget);
      expect(find.text('Bedside Light'), findsOneWidget);
      expect(find.text('Bedroom Fan'), findsOneWidget);
      expect(find.text('Smart Light'), findsNothing);
      expect(find.text('Kitchen Light'), findsNothing);

      await tester.tap(find.text('Kitchen'));
      await tester.pumpAndSettle();

      expect(find.text('1 devices'), findsOneWidget);
      expect(find.text('Kitchen Light'), findsOneWidget);
      expect(find.text('Bedside Light'), findsNothing);
      expect(find.text('Smart Light'), findsNothing);

      await tester.tap(find.text('Living Room'));
      await tester.pumpAndSettle();

      expect(find.text('3 devices'), findsOneWidget);
      expect(find.text('Smart Light'), findsOneWidget);
    });

    testWidgets('tapping power switch updates UI and device state',
        (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      // Initially Smart Light and Home Security are On; Smart Fan is Off
      expect(find.byIcon(Icons.toggle_on_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.toggle_off_rounded), findsOneWidget);

      // Tap Smart Light card to turn it off
      await tester.tap(find.byIcon(Icons.toggle_on_rounded).first);
      await tester.pump();
      await tester.pumpAndSettle();

      // Now only Home Security is On; Smart Light and Smart Fan are Off
      expect(find.byIcon(Icons.toggle_on_rounded), findsOneWidget);
      expect(find.byIcon(Icons.toggle_off_rounded), findsNWidgets(2));
      expect(
        repository.devices.firstWhere((d) => d.id == 'light-1').isOn,
        isFalse,
      );

      // Tap Smart Light card again to turn back on
      await tester.tap(find.byIcon(Icons.toggle_off_rounded).first);
      await tester.pump();
      await tester.pumpAndSettle();

      // Back to 2 On (Smart Light & Home Security) and 1 Off (Smart Fan)
      expect(
        repository.devices.firstWhere((d) => d.id == 'light-1').isOn,
        isTrue,
      );
      expect(find.byIcon(Icons.toggle_on_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.toggle_off_rounded), findsOneWidget);
    });
  });
}
