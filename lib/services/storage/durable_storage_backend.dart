import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'storage_adapter.dart';
import 'storage_adapter_stub.dart';
import 'storage_exceptions.dart';

/// Simple asynchronous FIFO lock for in-process key serialization.
class _AsyncLock {
  Future<void>? _last;

  Future<T> synchronized<T>(Future<T> Function() action) {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;

    return Future.sync(() async {
      if (prev != null) {
        try {
          await prev;
        } catch (_) {}
      }
      try {
        return await action();
      } finally {
        completer.complete();
      }
    });
  }
}

/// Durable file-backed storage backend implementing crash-safe atomic staging,
/// in-process mutex synchronization, explicit error reporting, and selective cleanup.
class DurableStorageBackend implements StorageAdapter {
  DurableStorageBackend({String? storagePath})
      : _storagePath = storagePath ?? resolveAppStoragePath();

  final String _storagePath;

  /// Returns the resolved directory path backing this storage backend.
  String get storagePath => _storagePath;

  /// Global in-process locks per key across all backend instances.
  static final Map<String, _AsyncLock> _keyLocks = {};

  /// Global in-process lock for directory-wide operations like clear().
  static final Map<String, _AsyncLock> _dirLocks = {};

  /// Process-level atomic counter to guarantee unique temp file names within a PID.
  static int _counter = 0;

  /// Lumivo committed file pattern: `<base64url_key>.val`
  static final RegExp _lumivoValPattern = RegExp(r'^[A-Za-z0-9_-]+\.val$');

  /// Lumivo temporary staged file pattern: `<base64url_key>.tmp.<pid>_<counter>_<time>`
  static final RegExp _lumivoTmpPattern =
      RegExp(r'^[A-Za-z0-9_-]+(\.val)?\.tmp(\..+)?$');

  /// Honest specification of multi-process and power-loss durability boundaries.
  static const String durabilityNotice =
      'Multi-process durability limits: last-write-wins model. '
      'Atomic replace via OS file rename guarantees non-torn reads, '
      'while in-process mutex queues ensure single-process serialization. '
      'Cross-process writes to the same key race at filesystem atomic rename. '
      'Physical power-loss durability is bounded by underlying OS/filesystem write-back caching policies.';

  /// Encodes arbitrary string keys into safe base64url file name components.
  static String encodeKey(String key) {
    final bytes = utf8.encode(key);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Checks if a file name matches Lumivo's committed or temporary storage format.
  static bool isLumivoStorageFile(String fileName) {
    return _lumivoValPattern.hasMatch(fileName) ||
        _lumivoTmpPattern.hasMatch(fileName);
  }

  /// Portable path join helper.
  static String joinPath(String dir, String file) {
    if (dir.isEmpty) return file;
    if (file.isEmpty) return dir;
    final cleanDir = dir.replaceAll(RegExp(r'[\\/]+$'), '');
    final cleanFile = file.replaceAll(RegExp(r'^[\\/]+'), '');
    final sep = Platform.isWindows && cleanDir.contains('\\') ? '\\' : '/';
    return '$cleanDir$sep$cleanFile';
  }

  /// Portable basename helper.
  static String getBasename(String path) {
    final clean = path.replaceAll(RegExp(r'[\\/]+$'), '');
    final idx = clean.lastIndexOf(RegExp(r'[\\/]'));
    return idx == -1 ? clean : clean.substring(idx + 1);
  }

  /// Portable dirname helper.
  static String getDirname(String path) {
    final clean = path.replaceAll(RegExp(r'[\\/]+$'), '');
    final idx = clean.lastIndexOf(RegExp(r'[\\/]'));
    if (idx == -1) return '.';
    if (idx == 0) return path.startsWith('\\') ? '\\' : '/';
    return clean.substring(0, idx);
  }

  /// Portable canonical path helper.
  static String canonicalize(String path) {
    final abs = Directory(path).absolute.path;
    return Platform.isWindows ? abs.toLowerCase().replaceAll('\\', '/') : abs;
  }

  static _AsyncLock _getKeyLock(String storageDir, String encodedKey) {
    final canonical = '${canonicalize(storageDir)}::$encodedKey';
    return _keyLocks.putIfAbsent(canonical, () => _AsyncLock());
  }

  static _AsyncLock _getDirLock(String storageDir) {
    final canonical = canonicalize(storageDir);
    return _dirLocks.putIfAbsent(canonical, () => _AsyncLock());
  }

  static String _generateTempFileName(String encodedKey) {
    final currentPid = pid;
    final currentCounter = ++_counter;
    final currentTime = DateTime.now().microsecondsSinceEpoch;
    return '$encodedKey.tmp.${currentPid}_${currentCounter}_$currentTime';
  }

  @override
  Future<String?> getString(String key) async {
    final encodedKey = encodeKey(key);
    final targetFilePath = joinPath(_storagePath, '$encodedKey.val');
    final file = File(targetFilePath);
    final lock = _getKeyLock(_storagePath, encodedKey);

    return await lock.synchronized(() async {
      FileSystemEntityType type;
      try {
        type = await FileSystemEntity.type(targetFilePath, followLinks: false);
      } catch (e) {
        throw StorageIOException(
          'Failed to check existence for key: $key',
          operation: 'get',
          targetKey: key,
          targetPath: targetFilePath,
          cause: e,
        );
      }

      if (type == FileSystemEntityType.notFound) {
        return null;
      }

      if (type != FileSystemEntityType.file) {
        throw StorageIOException(
          'Target path is not a regular file: $targetFilePath (type: $type)',
          operation: 'get',
          targetKey: key,
          targetPath: targetFilePath,
        );
      }

      try {
        return await file.readAsString();
      } catch (e) {
        throw StorageIOException(
          'Failed to read storage key: $key',
          operation: 'get',
          targetKey: key,
          targetPath: targetFilePath,
          cause: e,
        );
      }
    });
  }

  /// Convenience alias for [getString].
  Future<String?> get(String key) => getString(key);

  @override
  Future<void> setString(
    String key,
    String value, {
    FutureOr<void> Function(File tempFile)? onStaged,
  }) async {
    final encodedKey = encodeKey(key);
    final lock = _getKeyLock(_storagePath, encodedKey);

    return await lock.synchronized(() async {
      // 1. Ensure storage directory exists
      final dir = Directory(_storagePath);
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (e) {
        throw StorageIOException(
          'Failed to create storage directory: $_storagePath',
          operation: 'set',
          targetKey: key,
          targetPath: _storagePath,
          cause: e,
        );
      }

      // 2. Prepare staging file in the SAME directory
      final tempFileName = _generateTempFileName(encodedKey);
      final tempFilePath = joinPath(_storagePath, tempFileName);
      final tempFile = File(tempFilePath);

      final targetFileName = '$encodedKey.val';
      final targetFilePath = joinPath(_storagePath, targetFileName);

      try {
        // 3. Write and flush staged temp file
        try {
          await tempFile.writeAsString(value, flush: true);
        } catch (e) {
          throw StorageIOException(
            'Failed to stage data to temporary file: $tempFilePath',
            operation: 'set',
            targetKey: key,
            targetPath: tempFilePath,
            cause: e,
          );
        }

        // 4. Staging hook (for child process probe testing or telemetry)
        if (onStaged != null) {
          try {
            await onStaged(tempFile);
          } catch (e) {
            throw StorageIOException(
              'Staging verification hook failed: $e',
              operation: 'set',
              targetKey: key,
              targetPath: tempFilePath,
              cause: e,
            );
          }
        }

        // 5. Atomic commit via rename
        // If rename fails, NEVER delete or truncate the old committed value
        try {
          await tempFile.rename(targetFilePath);
        } catch (renameError) {
          throw StorageIOException(
            'Atomic replace failed to rename staged file to target file',
            operation: 'set',
            targetKey: key,
            targetPath: targetFilePath,
            cause: renameError,
          );
        }
      } catch (originalException) {
        // Clean owned temp file without hiding original exception
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}

        if (originalException is StorageIOException) {
          rethrow;
        }
        throw StorageIOException(
          'Durable write failed for key: $key',
          operation: 'set',
          targetKey: key,
          targetPath: targetFilePath,
          cause: originalException,
        );
      }
    });
  }

  /// Convenience alias for [setString].
  Future<void> set(String key, String value) => setString(key, value);

  @override
  Future<void> remove(String key) async {
    final encodedKey = encodeKey(key);
    final targetFilePath = joinPath(_storagePath, '$encodedKey.val');
    final file = File(targetFilePath);
    final lock = _getKeyLock(_storagePath, encodedKey);

    await lock.synchronized(() async {
      FileSystemEntityType type;
      try {
        type = await FileSystemEntity.type(targetFilePath, followLinks: false);
      } catch (e) {
        throw StorageIOException(
          'Failed to check existence for remove: $key',
          operation: 'remove',
          targetKey: key,
          targetPath: targetFilePath,
          cause: e,
        );
      }

      if (type == FileSystemEntityType.notFound) {
        return;
      }

      try {
        await file.delete();
      } catch (e) {
        throw StorageIOException(
          'Failed to delete storage file for key: $key',
          operation: 'remove',
          targetKey: key,
          targetPath: targetFilePath,
          cause: e,
        );
      }
    });
  }

  @override
  Future<void> clear() async {
    final dir = Directory(_storagePath);
    final dirLock = _getDirLock(_storagePath);

    await dirLock.synchronized(() async {
      bool exists;
      try {
        exists = await dir.exists();
      } catch (e) {
        throw StorageIOException(
          'Failed to check storage directory existence for clear',
          operation: 'clear',
          targetPath: _storagePath,
          cause: e,
        );
      }

      if (!exists) {
        return;
      }

      List<FileSystemEntity> entities;
      try {
        entities = await dir.list().toList();
      } catch (e) {
        throw StorageIOException(
          'Failed to list storage directory contents for clear',
          operation: 'clear',
          targetPath: _storagePath,
          cause: e,
        );
      }

      for (final entity in entities) {
        if (entity is File) {
          final fileName = getBasename(entity.path);
          if (isLumivoStorageFile(fileName)) {
            try {
              await entity.delete();
            } catch (e) {
              throw StorageIOException(
                'Failed to delete storage file during clear: $fileName',
                operation: 'clear',
                targetPath: entity.path,
                cause: e,
              );
            }
          }
        }
      }
    });
  }

  /// Cleans up any orphaned temp files (e.g. left by killed processes).
  Future<int> cleanDanglingTempFiles() async {
    final dir = Directory(_storagePath);
    if (!await dir.exists()) {
      return 0;
    }

    var count = 0;
    List<FileSystemEntity> entities;
    try {
      entities = await dir.list().toList();
    } catch (_) {
      return 0;
    }

    for (final entity in entities) {
      if (entity is File) {
        final fileName = getBasename(entity.path);
        if (_lumivoTmpPattern.hasMatch(fileName)) {
          try {
            await entity.delete();
            count++;
          } catch (_) {}
        }
      }
    }
    return count;
  }
}
