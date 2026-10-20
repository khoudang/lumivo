import 'storage_adapter.dart';
import 'storage_adapter_stub.dart'
    if (dart.library.html) 'storage_adapter_web.dart';

abstract final class StorageAdapterFactory {
  static StorageAdapter? _mockAdapter;

  static void setMockAdapter(StorageAdapter? adapter) {
    _mockAdapter = adapter;
  }

  static StorageAdapter create() {
    return _mockAdapter ?? createStorageAdapter();
  }
}
