import 'platform_storage_resolver.dart';
import 'storage_adapter.dart';
import 'storage_adapter_stub.dart'
    if (dart.library.html) 'storage_adapter_web.dart';

abstract final class StorageAdapterFactory {
  static StorageAdapter? _mockAdapter;
  static String? _resolvedStoragePath;

  static void setMockAdapter(StorageAdapter? adapter) {
    _mockAdapter = adapter;
  }

  /// Asynchronously resolves and caches the platform storage directory prior
  /// to synchronous calls to [create].
  static Future<void> bootstrap({String? storagePath}) async {
    if (storagePath != null && storagePath.trim().isNotEmpty) {
      _resolvedStoragePath = storagePath.trim();
    } else {
      _resolvedStoragePath = await PlatformStorageResolver.resolve();
    }
  }

  /// Resets mock adapter and cached bootstrap state.
  static void reset() {
    _mockAdapter = null;
    _resolvedStoragePath = null;
  }

  /// Creates a [StorageAdapter]. Returns mock adapter if registered,
  /// otherwise delegates to native durable storage backend.
  static StorageAdapter create([String? storagePath]) {
    if (_mockAdapter != null) {
      return _mockAdapter!;
    }
    final path = storagePath ?? _resolvedStoragePath;
    if (path != null) {
      return createStorageAdapter(path);
    }
    return createStorageAdapter();
  }
}
