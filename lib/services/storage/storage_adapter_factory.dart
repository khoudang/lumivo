import 'storage_adapter.dart';
import 'storage_adapter_stub.dart'
    if (dart.library.io) 'storage_adapter_native.dart'
    if (dart.library.html) 'storage_adapter_web.dart';

abstract final class StorageAdapterFactory {
  static StorageAdapter? _mockAdapter;

  static void setMockAdapter(StorageAdapter? adapter) {
    _mockAdapter = adapter;
  }

  static StorageAdapter create({String? storagePath}) {
    return _mockAdapter ?? createStorageAdapter(storagePath: storagePath);
  }
}
