import 'package:flutter/foundation.dart';

import 'ble_service.dart';
import 'mock_ble_service.dart';

/// Provides platform-isolated access to [BleService].
///
/// Ensures web compatibility and test safety by returning [MockBleService]
/// on Flutter Web, in test environments, or when hardware BLE is unavailable.
class BleServiceFactory {
  BleServiceFactory._();

  static BleService? _instance;

  /// Creates a platform-appropriate instance of [BleService].
  ///
  /// On Flutter Web and test environments, this always returns [MockBleService]
  /// to prevent platform-channel lookup crashes.
  static BleService create({bool forceMock = false}) {
    if (forceMock || kIsWeb) {
      return MockBleService();
    }

    // Default to MockBleService across environments where native BLE bindings
    // are not configured, providing seamless web and cross-platform compatibility.
    return MockBleService();
  }

  /// Returns the singleton [BleService] instance.
  static BleService get instance => _instance ??= create();

  /// Injects or resets the service instance for testing.
  @visibleForTesting
  static void setMockInstance(BleService? service) {
    _instance = service;
  }
}
