import 'package:flutter/foundation.dart';
import '../../../core/models/discovered_device.dart';
import '../../../core/models/provisioning_state.dart';

@immutable
class OnboardingState {
  const OnboardingState({
    this.discoveredDevices = const [],
    this.selectedDevice,
    this.isScanning = false,
    this.provisioningProgress,
    this.errorMessage,
    this.isCompleted = false,
  });

  final List<DiscoveredDevice> discoveredDevices;
  final DiscoveredDevice? selectedDevice;
  final bool isScanning;
  final ProvisioningProgress? provisioningProgress;
  final String? errorMessage;
  final bool isCompleted;

  factory OnboardingState.initial() => const OnboardingState();

  OnboardingState copyWith({
    List<DiscoveredDevice>? discoveredDevices,
    DiscoveredDevice? selectedDevice,
    bool? isScanning,
    ProvisioningProgress? provisioningProgress,
    String? errorMessage,
    bool? isCompleted,
    bool clearSelectedDevice = false,
    bool clearProvisioningProgress = false,
    bool clearErrorMessage = false,
  }) {
    return OnboardingState(
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      selectedDevice:
          clearSelectedDevice ? null : (selectedDevice ?? this.selectedDevice),
      isScanning: isScanning ?? this.isScanning,
      provisioningProgress: clearProvisioningProgress
          ? null
          : (provisioningProgress ?? this.provisioningProgress),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingState &&
        listEquals(other.discoveredDevices, discoveredDevices) &&
        other.selectedDevice == selectedDevice &&
        other.isScanning == isScanning &&
        other.provisioningProgress == provisioningProgress &&
        other.errorMessage == errorMessage &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(discoveredDevices),
        selectedDevice,
        isScanning,
        provisioningProgress,
        errorMessage,
        isCompleted,
      );

  @override
  String toString() =>
      'OnboardingState(devices: ${discoveredDevices.length}, selected: ${selectedDevice?.name}, isScanning: $isScanning, progress: ${provisioningProgress?.step}, isCompleted: $isCompleted, error: $errorMessage)';
}
