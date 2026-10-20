import '../../core/models/discovered_device.dart';
import '../../core/models/provisioning_state.dart';

abstract interface class ProvisioningService {
  Stream<ProvisioningProgress> provision({
    required DiscoveredDevice device,
    required String ssid,
    required String password,
  });
  Future<void> cancel();
}
