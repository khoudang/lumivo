enum ProvisioningStep {
  idle,
  discovering,
  connectingBle,
  sendingCredentials,
  waitingDeviceJoin,
  verifyingMqtt,
  completed,
  failed,
}

class ProvisioningProgress {
  const ProvisioningProgress({
    required this.step,
    required this.progress,
    required this.message,
    this.errorMessage,
    this.provisionedDeviceId,
  });

  final ProvisioningStep step;
  final double progress;
  final String message;
  final String? errorMessage;
  final String? provisionedDeviceId;

  bool get isCompleted => step == ProvisioningStep.completed;
  bool get hasFailed => step == ProvisioningStep.failed;
}
