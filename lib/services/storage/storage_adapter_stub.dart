import 'durable_storage_backend.dart';
import 'platform_storage_resolver.dart';
import 'storage_adapter.dart';
import 'storage_exceptions.dart';

/// Synchronously resolves application persistent storage path.
/// Throws [StoragePathException] if the platform requires asynchronous path_provider resolution.
String resolveAppStoragePath() {
  final syncPath = PlatformStorageResolver.resolveSync();
  if (syncPath != null) {
    return syncPath;
  }
  throw const StoragePathException(
    'Failed to resolve platform storage path synchronously. '
    'Asynchronous resolution via PlatformStorageResolver.resolve() is required on this platform.',
  );
}

/// Durable file-backed storage adapter for native platforms.
class DurableStorageAdapter implements StorageAdapter {
  DurableStorageAdapter({String? storagePath}) : _storagePath = storagePath {
    final configured = _storagePath;
    if (configured != null && configured.isNotEmpty) {
      _resolvedPath = configured;
      _backend = DurableStorageBackend(storagePath: configured);
    } else {
      final sync = PlatformStorageResolver.resolveSync();
      if (sync != null && sync.isNotEmpty) {
        _resolvedPath = sync;
        _backend = DurableStorageBackend(storagePath: sync);
      }
    }
  }

  final String? _storagePath;
  String? _resolvedPath;
  DurableStorageBackend? _backend;

  Future<DurableStorageBackend> _getBackend() async {
    final existing = _backend;
    if (existing != null) return existing;
    final path = await _getPath();
    final backend = DurableStorageBackend(storagePath: path);
    _backend = backend;
    return backend;
  }

  Future<String> _getPath() async {
    final configured = _storagePath;
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    final cached = _resolvedPath;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final sync = PlatformStorageResolver.resolveSync();
    if (sync != null && sync.isNotEmpty) {
      _resolvedPath = sync;
      return sync;
    }
    final asyncResolved = await PlatformStorageResolver.resolve();
    _resolvedPath = asyncResolved;
    return asyncResolved;
  }

  @override
  Future<String?> getString(String key) {
    final b = _backend;
    if (b != null) return b.getString(key);
    return _getStringAsync(key);
  }

  Future<String?> _getStringAsync(String key) async {
    final b = await _getBackend();
    return b.getString(key);
  }

  @override
  Future<void> setString(String key, String value) {
    final b = _backend;
    if (b != null) return b.setString(key, value);
    return _setStringAsync(key, value);
  }

  Future<void> _setStringAsync(String key, String value) async {
    final b = await _getBackend();
    return b.setString(key, value);
  }

  @override
  Future<void> remove(String key) {
    final b = _backend;
    if (b != null) return b.remove(key);
    return _removeAsync(key);
  }

  Future<void> _removeAsync(String key) async {
    final b = await _getBackend();
    return b.remove(key);
  }

  @override
  Future<void> clear() {
    final b = _backend;
    if (b != null) return b.clear();
    return _clearAsync();
  }

  Future<void> _clearAsync() async {
    final b = await _getBackend();
    return b.clear();
  }
}

/// StorageAdapterImpl provides an isolated in-memory adapter when constructed
/// directly as a test fixture, or delegates to durable file storage when a
/// storage path is configured.
class StorageAdapterImpl implements StorageAdapter {
  StorageAdapterImpl({this.storagePath});

  final String? storagePath;
  final Map<String, String> _memory = {};
  late final DurableStorageAdapter? _durable =
      storagePath != null ? DurableStorageAdapter(storagePath: storagePath) : null;

  /// True when this adapter is operating in isolated in-memory mode without disk writes.
  bool get isInMemory => _durable == null;

  @override
  Future<String?> getString(String key) async {
    final durable = _durable;
    if (durable != null) return durable.getString(key);
    return _memory[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    final durable = _durable;
    if (durable != null) return durable.setString(key, value);
    _memory[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    final durable = _durable;
    if (durable != null) return durable.remove(key);
    _memory.remove(key);
  }

  @override
  Future<void> clear() async {
    final durable = _durable;
    if (durable != null) return durable.clear();
    _memory.clear();
  }
}

StorageAdapter createStorageAdapter([String? storagePath]) =>
    DurableStorageAdapter(storagePath: storagePath);
