import 'dart:convert';
import 'dart:io';

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
  DurableStorageAdapter({String? storagePath}) : _storagePath = storagePath;

  final String? _storagePath;
  String? _resolvedPath;

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

  String _keyToFileName(String key) {
    final bytes = utf8.encode(key);
    final encoded = base64Url.encode(bytes).replaceAll('=', '');
    return '$encoded.val';
  }

  @override
  Future<String?> getString(String key) async {
    final storagePath = await _getPath();
    final file = File('$storagePath/${_keyToFileName(key)}');
    if (!file.existsSync()) {
      return null;
    }
    try {
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    final storagePath = await _getPath();
    final dir = Directory(storagePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final targetPath = '$storagePath/${_keyToFileName(key)}';
    final tmpPath =
        '$storagePath/${_keyToFileName(key)}.${DateTime.now().microsecondsSinceEpoch}.tmp';
    final tmpFile = File(tmpPath);
    tmpFile.writeAsStringSync(value, flush: true);
    try {
      tmpFile.renameSync(targetPath);
    } catch (_) {
      try {
        final targetFile = File(targetPath);
        if (targetFile.existsSync()) {
          targetFile.deleteSync();
        }
      } catch (_) {}
      try {
        tmpFile.renameSync(targetPath);
      } catch (_) {
        File(targetPath).writeAsStringSync(value, flush: true);
        try {
          if (tmpFile.existsSync()) {
            tmpFile.deleteSync();
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> remove(String key) async {
    final storagePath = await _getPath();
    final file = File('$storagePath/${_keyToFileName(key)}');
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    final storagePath = await _getPath();
    final dir = Directory(storagePath);
    if (dir.existsSync()) {
      try {
        for (final entity in dir.listSync()) {
          if (entity is File) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
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
