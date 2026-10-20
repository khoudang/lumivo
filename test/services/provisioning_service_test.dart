import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/discovered_device.dart';
import 'package:lumivo/core/models/provisioning_state.dart';
import 'package:lumivo/core/models/smart_device.dart';
import 'package:lumivo/services/provisioning/mock_provisioning_service.dart';

void main() {
  group('MockProvisioningService', () {
    late MockProvisioningService service;
    const testDevice = DiscoveredDevice(
      id: 'lumivo-bulb-01',
      name: 'Lumivo Bulb A19',
      rssi: -55,
      type: DeviceType.light,
    );

    setUp(() {
      service =
          MockProvisioningService(stepDelay: const Duration(milliseconds: 10));
    });

    test('executes successful 5-step provisioning state machine', () async {
      final progressList = await service
          .provision(
            device: testDevice,
            ssid: 'LumivoHome-5G',
            password: 'secretpassword',
          )
          .toList();

      expect(progressList.length, equals(5));

      // Step 1: connectingBle (15%)
      expect(progressList[0].step, equals(ProvisioningStep.connectingBle));
      expect(progressList[0].progress, equals(0.15));

      // Step 2: sendingCredentials (45%)
      expect(progressList[1].step, equals(ProvisioningStep.sendingCredentials));
      expect(progressList[1].progress, equals(0.45));

      // Step 3: waitingDeviceJoin (75%)
      expect(progressList[2].step, equals(ProvisioningStep.waitingDeviceJoin));
      expect(progressList[2].progress, equals(0.75));

      // Step 4: verifyingMqtt (90%)
      expect(progressList[3].step, equals(ProvisioningStep.verifyingMqtt));
      expect(progressList[3].progress, equals(0.90));

      // Step 5: completed (100%)
      expect(progressList[4].step, equals(ProvisioningStep.completed));
      expect(progressList[4].progress, equals(1.0));
      expect(progressList[4].provisionedDeviceId, equals(testDevice.id));
      expect(progressList[4].isCompleted, isTrue);
    });

    test('emits failed step when SSID is BadWifi', () async {
      final progressList = await service
          .provision(
            device: testDevice,
            ssid: 'BadWifi',
            password: 'secretpassword',
          )
          .toList();

      final last = progressList.last;
      expect(last.step, equals(ProvisioningStep.failed));
      expect(last.hasFailed, isTrue);
      expect(last.errorMessage, contains('BadWifi'));
    });

    test('emits failed step when password is wrong', () async {
      final progressList = await service
          .provision(
            device: testDevice,
            ssid: 'LumivoHome-5G',
            password: 'wrong',
          )
          .toList();

      final last = progressList.last;
      expect(last.step, equals(ProvisioningStep.failed));
      expect(last.hasFailed, isTrue);
      expect(last.errorMessage, contains('Invalid Wi-Fi password'));
    });

    test('cancel() aborts the active stream', () async {
      final serviceWithDelay = MockProvisioningService(
        stepDelay: const Duration(milliseconds: 100),
      );

      final events = <ProvisioningProgress>[];
      final subscription = serviceWithDelay
          .provision(
            device: testDevice,
            ssid: 'LumivoHome-5G',
            password: 'secretpassword',
          )
          .listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await serviceWithDelay.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Should have only received the first step, not completed
      expect(events.length, lessThan(5));
      expect(events.any((e) => e.step == ProvisioningStep.completed), isFalse);

      await subscription.cancel();
    });
  });
}
