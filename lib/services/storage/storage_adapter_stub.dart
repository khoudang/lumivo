import 'storage_adapter.dart';

class StorageAdapterImpl implements StorageAdapter {
  final Map<String, String> _memory = {};

  @override
  Future<String?> getString(String key) async {
    return _memory[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    _memory[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _memory.remove(key);
  }

  @override
  Future<void> clear() async {
    _memory.clear();
  }
}

StorageAdapter createStorageAdapter({String? storagePath}) =>
    StorageAdapterImpl();
