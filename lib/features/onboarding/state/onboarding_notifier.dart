import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/discovered_device.dart';
import '../../../core/models/provisioning_state.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/repositories/device_repository.dart';
import '../../../services/ble/ble_service.dart';
import '../../../services/mock/mock_device_repository.dart';
import '../../../services/mock/mock_discovered_devices.dart';
import '../../../services/provisioning/provisioning_service.dart';
import 'onboarding_state.dart';

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier({
    DeviceRepository? deviceRepository,
    BleService? bleService,
    ProvisioningService? provisioningService,
  })  : _deviceRepository = deviceRepository ?? MockDeviceRepository(),
        _bleService = bleService,
        _provisioningService = provisioningService,
        super(const OnboardingState());

  final DeviceRepository _deviceRepository;
  final BleService? _bleService;
  final ProvisioningService? _provisioningService;

  StreamSubscription<List<DiscoveredDevice>>? _scanSubscription;

  Future<void> startScan({BleService? bleService}) async {
    final service = bleService ?? _bleService;
    state = state.copyWith(
      isScanning: true,
      clearErrorMessage: true,
    );
    await _scanSubscription?.cancel();
    if (service != null) {
      _scanSubscription = service.discoveredDevices.listen((devices) {
        if (mounted) {
          state = state.copyWith(discoveredDevices: devices);
        }
      });
      try {
        await service.startScan();
      } catch (e) {
        if (mounted) {
          state = state.copyWith(
            errorMessage: 'Scan failed: $e',
            isScanning: false,
          );
        }
      }
    } else {
      state = state.copyWith(
        discoveredDevices: mockDiscoveredDevices,
        isScanning: true,
      );
    }
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    final service = _bleService;
    if (service != null) {
      try {
        await service.stopScan();
      } catch (_) {}
    }
    state = state.copyWith(isScanning: false);
  }

  void selectDevice(DiscoveredDevice device) {
    state = state.copyWith(selectedDevice: device);
  }

  Future<void> provision({
    required String ssid,
    required String password,
    ProvisioningService? provisioningService,
  }) async {
    final device = state.selectedDevice;
    if (device == null) {
      state = state.copyWith(
        errorMessage: 'No device selected for provisioning',
      );
      return;
    }

    await stopScan();

    state = state.copyWith(
      clearErrorMessage: true,
      isCompleted: false,
      provisioningProgress: const ProvisioningProgress(
        step: ProvisioningStep.connectingBle,
        progress: 0.1,
        message: 'Connecting to device...',
      ),
    );

    final service = provisioningService ?? _provisioningService;
    if (service != null) {
      try {
        await for (final progress in service.provision(
          device: device,
          ssid: ssid,
          password: password,
        )) {
          if (!mounted) return;
          if (progress.hasFailed) {
            state = state.copyWith(
              provisioningProgress: progress,
              errorMessage: progress.errorMessage ?? progress.message,
              isCompleted: false,
            );
            return;
          } else if (progress.isCompleted) {
            _registerDevice(device);
            state = state.copyWith(
              provisioningProgress: progress,
              isCompleted: true,
              clearErrorMessage: true,
            );
            return;
          } else {
            state = state.copyWith(
              provisioningProgress: progress,
              isCompleted: false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          state = state.copyWith(
            provisioningProgress: ProvisioningProgress(
              step: ProvisioningStep.failed,
              progress: 0.0,
              message: e.toString(),
              errorMessage: e.toString(),
            ),
            errorMessage: e.toString(),
            isCompleted: false,
          );
        }
      }
    } else {
      final steps = [
        const ProvisioningProgress(
          step: ProvisioningStep.connectingBle,
          progress: 0.25,
          message: 'Connected via BLE',
        ),
        const ProvisioningProgress(
          step: ProvisioningStep.sendingCredentials,
          progress: 0.5,
          message: 'Credentials sent to device',
        ),
        const ProvisioningProgress(
          step: ProvisioningStep.waitingDeviceJoin,
          progress: 0.75,
          message: 'Device joined Wi-Fi',
        ),
        const ProvisioningProgress(
          step: ProvisioningStep.verifyingMqtt,
          progress: 0.9,
          message: 'MQTT connection verified',
        ),
        ProvisioningProgress(
          step: ProvisioningStep.completed,
          progress: 1.0,
          message: 'Device successfully provisioned!',
          provisionedDeviceId: device.id,
        ),
      ];

      for (final step in steps) {
        if (!mounted) return;
        state = state.copyWith(
          provisioningProgress: step,
          isCompleted: step.isCompleted,
        );
        if (step.isCompleted) {
          _registerDevice(device);
        }
      }
    }
  }

  void _registerDevice(DiscoveredDevice target) {
    final smartDevice = SmartDevice(
      id: target.id,
      name: target.name,
      roomId: 'Living Room',
      type: target.type,
      isOn: true,
      brightness: 100,
      connection: DeviceConnection.online,
    );
    final repo = _deviceRepository;
    if (repo is MockDeviceRepository) {
      repo.addDevice(smartDevice);
    } else {
      try {
        (repo as dynamic).addDevice(smartDevice);
      } catch (_) {}
    }
  }

  void simulateFailure([String error = 'Wi-Fi authentication failed']) {
    state = state.copyWith(
      provisioningProgress: ProvisioningProgress(
        step: ProvisioningStep.failed,
        progress: 0.0,
        message: error,
        errorMessage: error,
      ),
      errorMessage: error,
      isCompleted: false,
      isScanning: false,
    );
  }

  void reset() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    state = const OnboardingState();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final deviceRepo = ref.watch(deviceRepositoryProvider);
  return OnboardingNotifier(deviceRepository: deviceRepo);
});

final onboardingNotifierProvider = onboardingProvider;
