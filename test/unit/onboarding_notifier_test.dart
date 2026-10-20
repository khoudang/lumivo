import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/discovered_device.dart';
import 'package:lumivo/core/models/provisioning_state.dart';
import 'package:lumivo/features/onboarding/state/onboarding_notifier.dart';
import 'package:lumivo/features/onboarding/state/onboarding_state.dart';
import 'package:lumivo/services/ble/ble_service.dart';
import 'package:lumivo/services/mock/mock_device_repository.dart';
import 'package:lumivo/services/mock/mock_discovered_devices.dart';
import 'package:lumivo/services/provisioning/provisioning_service.dart';

class FakeBleService implements BleService {
  final _controller = StreamController<List<DiscoveredDevice>>.broadcast();
  bool scanStarted = false;
  bool scanStopped = false;

  @override
  bool get isSupported => true;

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices => _controller.stream;

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    scanStarted = true;
    _controller.add(mockDiscoveredDevices);
  }

  @override
  Future<void> stopScan() async {
    scanStopped = true;
  }

  @override
  Future<bool> connect(String deviceId) async => true;

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeProvisioningService implements ProvisioningService {
  FakeProvisioningService({this.shouldFail = false, this.errorMessage});

  final bool shouldFail;
  final String? errorMessage;
  bool wasCancelled = false;

  @override
  Stream<ProvisioningProgress> provision({
    required DiscoveredDevice device,
    required String ssid,
    required String password,
  }) async* {
    yield const ProvisioningProgress(
      step: ProvisioningStep.connectingBle,
      progress: 0.2,
      message: 'Connecting to device...',
    );
    yield const ProvisioningProgress(
      step: ProvisioningStep.sendingCredentials,
      progress: 0.5,
      message: 'Sending credentials...',
    );
    if (shouldFail) {
      yield ProvisioningProgress(
        step: ProvisioningStep.failed,
        progress: 0.5,
        message: errorMessage ?? 'Wi-Fi connection failed',
        errorMessage: errorMessage ?? 'Wi-Fi connection failed',
      );
      return;
    }
    yield const ProvisioningProgress(
      step: ProvisioningStep.waitingDeviceJoin,
      progress: 0.75,
      message: 'Device connecting...',
    );
    yield const ProvisioningProgress(
      step: ProvisioningStep.verifyingMqtt,
      progress: 0.9,
      message: 'Verifying MQTT...',
    );
    yield ProvisioningProgress(
      step: ProvisioningStep.completed,
      progress: 1.0,
      message: 'Device successfully connected!',
      provisionedDeviceId: device.id,
    );
  }

  @override
  Future<void> cancel() async {
    wasCancelled = true;
  }
}

void main() {
  group('OnboardingNotifier Unit Tests', () {
    late MockDeviceRepository repository;
    late OnboardingNotifier notifier;

    setUp(() {
      repository = MockDeviceRepository(responseDelay: Duration.zero);
      notifier = OnboardingNotifier(deviceRepository: repository);
    });

    tearDown(() async {
      notifier.dispose();
      await repository.dispose();
    });

    test('startScan populates discovered devices and toggles isScanning',
        () async {
      expect(notifier.state.isScanning, isFalse);
      expect(notifier.state.discoveredDevices, isEmpty);

      // Start scan with default fallback
      await notifier.startScan();
      expect(notifier.state.isScanning, isTrue);
      expect(notifier.state.discoveredDevices, mockDiscoveredDevices);

      await notifier.stopScan();
      expect(notifier.state.isScanning, isFalse);

      // Start scan with custom BleService
      final fakeBle = FakeBleService();
      await notifier.startScan(bleService: fakeBle);
      expect(fakeBle.scanStarted, isTrue);
      expect(notifier.state.isScanning, isTrue);
      expect(notifier.state.discoveredDevices, mockDiscoveredDevices);

      await notifier.stopScan();
      expect(notifier.state.isScanning, isFalse);
      await fakeBle.dispose();
    });

    test('selectDevice updates selected device in state', () {
      expect(notifier.state.selectedDevice, isNull);

      final device = mockDiscoveredDevices[1]; // Lumivo Breeze Fan
      notifier.selectDevice(device);

      expect(notifier.state.selectedDevice, device);
      expect(notifier.state.selectedDevice?.id, 'lumivo-fan-01');
      expect(notifier.state.selectedDevice?.name, 'Lumivo Breeze Fan');
    });

    test(
        'provisioning success transitions, completes, and registers new device',
        () async {
      final initialCount = repository.devices.length;
      final target = mockDiscoveredDevices.first; // Lumivo Aura Bulb
      notifier.selectDevice(target);

      final fakeProvisioning = FakeProvisioningService();
      await notifier.provision(
        ssid: 'Home_WiFi_5G',
        password: 'securePassword123',
        provisioningService: fakeProvisioning,
      );

      expect(notifier.state.isCompleted, isTrue);
      expect(
        notifier.state.provisioningProgress?.step,
        ProvisioningStep.completed,
      );
      expect(notifier.state.errorMessage, isNull);

      // Device registered in DeviceRepository
      expect(repository.devices.length, initialCount + 1);
      final registered =
          repository.devices.firstWhere((d) => d.id == target.id);
      expect(registered.name, target.name);
      expect(registered.type, target.type);
      expect(registered.isOn, isTrue);
    });

    test('provisioning runs default simulation when no service provided',
        () async {
      final initialCount = repository.devices.length;
      final target = mockDiscoveredDevices[1]; // Lumivo Breeze Fan
      notifier.selectDevice(target);

      await notifier.provision(
        ssid: 'Home_WiFi',
        password: 'pwd',
      );

      expect(notifier.state.isCompleted, isTrue);
      expect(
        notifier.state.provisioningProgress?.step,
        ProvisioningStep.completed,
      );
      expect(repository.devices.length, initialCount + 1);
      expect(repository.devices.any((d) => d.id == target.id), isTrue);
    });

    test('provisioning failure handling via service and simulateFailure',
        () async {
      // 1. Service failure
      final target = mockDiscoveredDevices[2];
      notifier.selectDevice(target);

      final failingService = FakeProvisioningService(
        shouldFail: true,
        errorMessage: 'Invalid Wi-Fi credentials',
      );

      await notifier.provision(
        ssid: 'Home_WiFi',
        password: 'wrong_password',
        provisioningService: failingService,
      );

      expect(notifier.state.isCompleted, isFalse);
      expect(
        notifier.state.provisioningProgress?.step,
        ProvisioningStep.failed,
      );
      expect(notifier.state.errorMessage, 'Invalid Wi-Fi credentials');

      // 2. simulateFailure method
      notifier.simulateFailure('Simulated Wi-Fi authentication failure');
      expect(notifier.state.isCompleted, isFalse);
      expect(
        notifier.state.errorMessage,
        'Simulated Wi-Fi authentication failure',
      );
      expect(
        notifier.state.provisioningProgress?.step,
        ProvisioningStep.failed,
      );

      // 3. Provisioning without selecting device fails with error
      notifier.reset();
      await notifier.provision(ssid: 'SSID', password: 'PWD');
      expect(
        notifier.state.errorMessage,
        'No device selected for provisioning',
      );
      expect(notifier.state.isCompleted, isFalse);
    });

    test('reset clears state to initial idle state', () async {
      await notifier.startScan();
      notifier.selectDevice(mockDiscoveredDevices.first);
      notifier.simulateFailure('Some error');

      expect(notifier.state.selectedDevice, isNotNull);
      expect(notifier.state.errorMessage, isNotNull);

      notifier.reset();

      expect(notifier.state, const OnboardingState());
      expect(notifier.state.isScanning, isFalse);
      expect(notifier.state.selectedDevice, isNull);
      expect(notifier.state.discoveredDevices, isEmpty);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.isCompleted, isFalse);
    });
  });
}
