import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/app/providers.dart';
import 'package:lumivo/features/onboarding/state/onboarding_notifier.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/mock/mock_discovered_devices.dart';

/// Test onboarding UI component that reflects the complete OnboardingState.
class TestOnboardingView extends ConsumerWidget {
  const TestOnboardingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Device')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error banner
            if (state.errorMessage != null) ...[
              Container(
                key: const ValueKey('error_banner'),
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade900,
                child: Text(
                  'Error: ${state.errorMessage}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Scanning indicator
            if (state.isScanning) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Scanning for Lumivo devices...'),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Discovered devices list
            if (state.discoveredDevices.isEmpty && !state.isScanning)
              const Center(child: Text('No devices found'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: state.discoveredDevices.length,
                  itemBuilder: (context, index) {
                    final device = state.discoveredDevices[index];
                    final isSelected = state.selectedDevice?.id == device.id;
                    return ListTile(
                      key: ValueKey('device_${device.id}'),
                      selected: isSelected,
                      title: Text(device.name),
                      subtitle: Text('RSSI: ${device.rssi} dBm'),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () => notifier.selectDevice(device),
                    );
                  },
                ),
              ),

            // Selected device info
            if (state.selectedDevice != null) ...[
              const Divider(),
              Text('Selected: ${state.selectedDevice!.name}'),
              const SizedBox(height: 8),
            ],

            // Provisioning progress
            if (state.provisioningProgress != null) ...[
              LinearProgressIndicator(
                value: state.provisioningProgress!.progress,
                key: const ValueKey('provisioning_progress_bar'),
              ),
              const SizedBox(height: 6),
              Text('Step: ${state.provisioningProgress!.step.name}'),
              Text(state.provisioningProgress!.message),
              const SizedBox(height: 8),
            ],

            // Completed banner
            if (state.isCompleted) ...[
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Pairing Complete!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('scan_button'),
                    onPressed: state.isScanning
                        ? () => notifier.stopScan()
                        : () => notifier.startScan(),
                    child: Text(state.isScanning ? 'Stop Scan' : 'Start Scan'),
                  ),
                ),
                const SizedBox(width: 8),
                if (state.selectedDevice != null && !state.isCompleted)
                  Expanded(
                    child: ElevatedButton(
                      key: const ValueKey('provision_button'),
                      onPressed: () => notifier.provision(
                        ssid: 'Home_WiFi',
                        password: 'secretPassword',
                      ),
                      child: const Text('Provision Device'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Onboarding State Rendering Widget Tests', () {
    late MockDeviceRepository repository;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
    });

    tearDown(() async {
      await repository.dispose();
    });

    Widget createWidget([OnboardingNotifier? customNotifier]) {
      return ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(repository),
          if (customNotifier != null)
            onboardingProvider.overrideWith((ref) => customNotifier),
        ],
        child: const MaterialApp(
          home: TestOnboardingView(),
        ),
      );
    }

    testWidgets(
        'renders initial idle state with Start Scan and No devices found',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Device'), findsOneWidget);
      expect(find.text('No devices found'), findsOneWidget);
      expect(find.text('Start Scan'), findsOneWidget);
      expect(find.text('Scanning for Lumivo devices...'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders scanning state with indicator and discovered devices',
        (WidgetTester tester) async {
      final notifier = OnboardingNotifier(deviceRepository: repository);
      await tester.pumpWidget(createWidget(notifier));
      await tester.pumpAndSettle();

      // Trigger scan
      await tester.tap(find.byKey(const ValueKey('scan_button')));
      await tester.pump();

      // Scanning indicator should be visible
      expect(find.text('Scanning for Lumivo devices...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Stop Scan'), findsOneWidget);

      // Discovered devices list rendered
      expect(find.text('Lumivo Aura Bulb'), findsOneWidget);
      expect(find.text('Lumivo Breeze Fan'), findsOneWidget);
      expect(find.text('Lumivo Guardian Cam'), findsOneWidget);
      expect(find.text('Lumivo Strip Light'), findsOneWidget);
      expect(find.text('RSSI: -52 dBm'), findsOneWidget);
    });

    testWidgets('renders selected device and displays Provision button',
        (WidgetTester tester) async {
      final notifier = OnboardingNotifier(deviceRepository: repository);
      await tester.pumpWidget(createWidget(notifier));
      await tester.pumpAndSettle();

      // Start scan and stop scan once devices populated
      await notifier.startScan();
      await notifier.stopScan();
      await tester.pumpAndSettle();

      // Tap on Lumivo Aura Bulb
      await tester.tap(find.text('Lumivo Aura Bulb'));
      await tester.pumpAndSettle();

      // Selected info and provision button visible
      expect(find.text('Selected: Lumivo Aura Bulb'), findsOneWidget);
      expect(find.byKey(const ValueKey('provision_button')), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets(
        'renders provisioning progress, step name, and completion banner',
        (WidgetTester tester) async {
      final notifier = OnboardingNotifier(deviceRepository: repository);
      await tester.pumpWidget(createWidget(notifier));
      await tester.pumpAndSettle();

      // Select device and provision
      notifier.selectDevice(mockBulb);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('provision_button')));
      await tester.pumpAndSettle();

      // Verify completion state
      expect(find.text('Pairing Complete!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Step: completed'), findsOneWidget);
      expect(find.text('Device successfully provisioned!'), findsOneWidget);
      expect(find.byKey(const ValueKey('provision_button')), findsNothing);
    });

    testWidgets('renders error banner when provisioning fails',
        (WidgetTester tester) async {
      final notifier = OnboardingNotifier(deviceRepository: repository);
      await tester.pumpWidget(createWidget(notifier));
      await tester.pumpAndSettle();

      notifier.simulateFailure('Authentication timeout');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('error_banner')), findsOneWidget);
      expect(find.text('Error: Authentication timeout'), findsOneWidget);
      expect(find.text('Step: failed'), findsOneWidget);
      expect(find.text('Pairing Complete!'), findsNothing);
    });
  });
}
