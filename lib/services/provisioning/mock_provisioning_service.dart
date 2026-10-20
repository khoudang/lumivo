import 'dart:async';

import '../../core/models/discovered_device.dart';
import '../../core/models/provisioning_state.dart';
import 'provisioning_service.dart';

/// Mock implementation of [ProvisioningService].
///
/// Implements a secure Wi-Fi provisioning state machine emitting [ProvisioningProgress]
/// through BLE connection, credential transfer, Wi-Fi join, and MQTT verification.
class MockProvisioningService implements ProvisioningService {
  MockProvisioningService({
    this.stepDelay = const Duration(milliseconds: 350),
  });

  final Duration stepDelay;

  StreamController<ProvisioningProgress>? _activeController;
  bool _isCancelled = false;

  @override
  Stream<ProvisioningProgress> provision({
    required DiscoveredDevice device,
    required String ssid,
    required String password,
  }) {
    // If a previous provisioning flow is active, cancel it first.
    _cancelActive();

    _isCancelled = false;
    final controller = StreamController<ProvisioningProgress>(
      onCancel: () {
        _isCancelled = true;
      },
    );
    _activeController = controller;

    _executeProvisioning(
      controller: controller,
      device: device,
      ssid: ssid,
      password: password,
    );

    return controller.stream;
  }

  Future<void> _executeProvisioning({
    required StreamController<ProvisioningProgress> controller,
    required DiscoveredDevice device,
    required String ssid,
    required String password,
  }) async {
    // Step 1: Connecting BLE (15% progress)
    if (_isCancelled || controller.isClosed) return;
    controller.add(
      ProvisioningProgress(
        step: ProvisioningStep.connectingBle,
        progress: 0.15,
        message: 'Connecting to ${device.name} via Bluetooth LE...',
      ),
    );

    if (stepDelay > Duration.zero) {
      await Future<void>.delayed(stepDelay);
    }
    if (_isCancelled || controller.isClosed) return;

    // Step 2: Sending Credentials (45% progress)
    controller.add(
      ProvisioningProgress(
        step: ProvisioningStep.sendingCredentials,
        progress: 0.45,
        message:
            'Encrypting and transmitting Wi-Fi credentials to ${device.name}...',
      ),
    );

    if (stepDelay > Duration.zero) {
      await Future<void>.delayed(stepDelay);
    }
    if (_isCancelled || controller.isClosed) return;

    // Error Handling: bad credentials or bad SSID
    if (ssid == 'BadWifi') {
      controller.add(
        ProvisioningProgress(
          step: ProvisioningStep.failed,
          progress: 0.45,
          message: 'Wi-Fi connection failed',
          errorMessage:
              'Unable to connect to Wi-Fi network "$ssid". Network not found or unreachable.',
        ),
      );
      await controller.close();
      return;
    }

    if (password == 'wrong') {
      controller.add(
        ProvisioningProgress(
          step: ProvisioningStep.failed,
          progress: 0.45,
          message: 'Authentication failed',
          errorMessage: 'Invalid Wi-Fi password provided for network "$ssid".',
        ),
      );
      await controller.close();
      return;
    }

    // Step 3: Waiting Device Join (75% progress)
    controller.add(
      ProvisioningProgress(
        step: ProvisioningStep.waitingDeviceJoin,
        progress: 0.75,
        message: 'Waiting for ${device.name} to associate with "$ssid"...',
      ),
    );

    if (stepDelay > Duration.zero) {
      await Future<void>.delayed(stepDelay);
    }
    if (_isCancelled || controller.isClosed) return;

    // Step 4: Verifying MQTT (90% progress)
    controller.add(
      const ProvisioningProgress(
        step: ProvisioningStep.verifyingMqtt,
        progress: 0.90,
        message: 'Verifying MQTT broker reachability and device handshake...',
      ),
    );

    if (stepDelay > Duration.zero) {
      await Future<void>.delayed(stepDelay);
    }
    if (_isCancelled || controller.isClosed) return;

    // Step 5: Completed (100% progress)
    controller.add(
      ProvisioningProgress(
        step: ProvisioningStep.completed,
        progress: 1.0,
        message: '${device.name} provisioned successfully.',
        provisionedDeviceId: device.id,
      ),
    );

    await controller.close();
  }

  void _cancelActive() {
    _isCancelled = true;
    if (_activeController != null && !_activeController!.isClosed) {
      _activeController!.close();
    }
    _activeController = null;
  }

  @override
  Future<void> cancel() async {
    _cancelActive();
  }
}
