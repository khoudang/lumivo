import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'storage_adapter.dart';
import 'storage_exceptions.dart';

/// Per-key async FIFO mutex/queue to serialize concurrent writes on the same key.
class _AsyncLock {
  Future<void>? _last;

  Future<T> synchronized<T>(FutureOr<T> Function() action) {
    final prev = _last;
    if (prev == null) {
      final completer = Completer<void>();
      _last = completer.future;
      try {
        final result = action();
        if (result is Future<T>) {
          return result.whenComplete(() {
            _last = null;
            completer.complete();
          });
        } else {
          _last = null;
          completer.complete();
          return Future.value(result);
        }
      } catch (e, st) {
        _last = null;
        completer.complete();
        return Future.error(e, st);
      }
    }

    final completer = Completer<void>();
    _last = completer.future;
    return prev.then((_) => action(), onError: (_) => action()).whenComplete(() {
      completer.complete();
    });
  }
}

/// Durable native storage backend implementing atomic file operations,
/// safe temporary staging, crash/abort resilience, and in-process concurrency safety.
///
/// Multi-Process Limitation Note:
/// In-process concurrency is strictly serialized via key-scoped mutex queues.
/// Across separate OS processes, atomic file replacement (staging + rename) guarantees
/// that readers will never observe truncated, partial, or malformed data.
/// However, separate processes writing to the identical key simultaneously operate under
/// "last-atomic-commit-wins" semantics. If multi-process distributed write coordination
/// is required in future architectures, an OS-level file lock (e.g. flock / LockFileEx)
/// or IPC coordinator should be layered on top of this backend.
class DurableStorageBackend implements StorageAdapter {
  DurableStorageBackend({String? storagePath})
      : _storagePath = storagePath ?? _defaultStoragePath();

  final String _storagePath;

  /// Returns the resolved directory path backing this storage backend.
  String get storagePath => _storagePath;

  static int _counter = 0;

  static final Map<String, _AsyncLock> _keyLocks = {};
  static final Map<String, _AsyncLock> _dirLocks = {};

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

  /// Checks if a file name matches Lumivo's committed or temporary storage format.
  static bool isLumivoStorageFile(String fileName) {
    return _lumivoValPattern.hasMatch(fileName) ||
        _lumivoTmpPattern.hasMatch(fileName);
  }

  static String _defaultStoragePath() {
    final envDir = Platform.environment['LUMIVO_STORAGE_DIR'];
    if (envDir != null && envDir.trim().isNotEmpty) {
      return envDir.trim();
    }
    return '.lumivo/storage';
  }

  /// Normalizes and canonicalizes a path for lock tracking.
  static String canonicalize(String path) {
    return path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+'), '/');
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

  /// Extracts the basename of a path.
  static String getBasename(String path) {
    final clean = path.replaceAll(RegExp(r'[\\/]+$'), '');
    final idx = clean.lastIndexOf(RegExp(r'[\\/]'));
    return idx == -1 ? clean : clean.substring(idx + 1);
  }

  /// Extracts the dirname of a path.
  static String getDirname(String path) {
    final clean = path.replaceAll(RegExp(r'[\\/]+$'), '');
    final idx = clean.lastIndexOf(RegExp(r'[\\/]'));
    if (idx == -1) return '.';
    if (idx == 0) return path.startsWith('\\') ? '\\' : '/';
    return clean.substring(0, idx);
  }

  /// Encodes a logical key into a filesystem-safe base64url string.
  static String encodeKey(String key) {
    final bytes = utf8.encode(key);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Validates key name to guard against path traversal attacks.
  static void validateKey(String key) {
    if (key.trim().isEmpty) {
      throw const StorageException('Storage key cannot be empty or blank');
    }
    if (key.contains('/') || key.contains('\\') || key.contains('..')) {
      throw StorageException('Storage key contains invalid path characters: $key');
    }
  }

  /// Generates a unique temporary staging filename in format:
  /// `<encodedKey>.tmp.<pid>_<counter>_<microseconds>`
  static String _generateTempFileName(String encodedKey) {
    final currentPid = pid;
    final currentCounter = ++_counter;
    final currentTime = DateTime.now().microsecondsSinceEpoch;
    return '$encodedKey.tmp.${currentPid}_${currentCounter}_$currentTime';
  }

  static _AsyncLock _getKeyLock(String storageDir, String encodedKey) {
    final canonical = '${canonicalize(storageDir)}::$encodedKey';
    return _keyLocks.putIfAbsent(canonical, () => _AsyncLock());
  }

  static _AsyncLock _getDirLock(String storageDir) {
    final canonical = canonicalize(storageDir);
    return _dirLocks.putIfAbsent(canonical, () => _AsyncLock());
  }

  @override
  Future<String?> getString(String key) {
    try {
      validateKey(key);
      final encodedKey = encodeKey(key);
      final targetFilePath = joinPath(_storagePath, '$encodedKey.val');
      final file = File(targetFilePath);

      FileSystemEntityType type;
      try {
        type = FileSystemEntity.typeSync(targetFilePath, followLinks: false);
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
        return Future.value(null);
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
        return Future.value(file.readAsStringSync());
      } catch (e) {
        throw StorageIOException(
          'Failed to read storage key: $key',
          operation: 'get',
          targetKey: key,
          targetPath: targetFilePath,
          cause: e,
        );
      }
    } catch (e, st) {
      return Future.error(e, st);
    }
  }

  /// Convenience alias for [getString].
  Future<String?> get(String key) => getString(key);

  @override
  Future<void> setString(
    String key,
    String value, {
    FutureOr<void> Function(File tempFile)? onStaged,
  }) {
    try {
      validateKey(key);
      final encodedKey = encodeKey(key);
      final lock = _getKeyLock(_storagePath, encodedKey);

      return lock.synchronized(() async {
        // 1. Ensure storage directory exists
        final dir = Directory(_storagePath);
        try {
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
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
            tempFile.writeAsStringSync(value, flush: true);
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
          try {
            tempFile.renameSync(targetFilePath);
          } catch (renameError) {
            // On Windows, rename fails if target already exists (OS Error 183).
            // Perform safe backup-and-swap so the old committed value is preserved if replacement fails.
            final targetFile = File(targetFilePath);
            if (targetFile.existsSync()) {
              final backupPath = joinPath(
                _storagePath,
                '$encodedKey.val.bak_${DateTime.now().microsecondsSinceEpoch}',
              );
              File? backupFile;
              try {
                backupFile = targetFile.renameSync(backupPath);
              } catch (_) {
                throw StorageIOException(
                  'Atomic replace failed: cannot stage old committed file for replacement',
                  operation: 'set',
                  targetKey: key,
                  targetPath: targetFilePath,
                  cause: renameError,
                );
              }

              try {
                tempFile.renameSync(targetFilePath);
                // Successfully committed new value; clean up backup
                try {
                  backupFile.deleteSync();
                } catch (_) {}
              } catch (swapErr) {
                // Replacement failed; restore old committed value immediately
                try {
                  backupFile.renameSync(targetFilePath);
                } catch (_) {}
                throw StorageIOException(
                  'Atomic replace failed: preserved original committed file',
                  operation: 'set',
                  targetKey: key,
                  targetPath: targetFilePath,
                  cause: swapErr,
                );
              }
            } else {
              throw StorageIOException(
                'Atomic replace failed to rename staged file to target file',
                operation: 'set',
                targetKey: key,
                targetPath: targetFilePath,
                cause: renameError,
              );
            }
          }
        } catch (originalException) {
          // Clean owned temp file without hiding original exception
          try {
            if (tempFile.existsSync()) {
              tempFile.deleteSync();
            }
          } catch (_) {}
          if (originalException is StorageException) {
            rethrow;
          }
          throw StorageIOException(
            'Storage operation failed: $originalException',
            operation: 'set',
            targetKey: key,
            targetPath: targetFilePath,
            cause: originalException,
          );
        }
      });
    } catch (e, st) {
      return Future.error(e, st);
    }
  }

  /// Convenience alias for [setString].
  Future<void> set(String key, String value) => setString(key, value);

  @override
  Future<void> remove(String key) {
    try {
      validateKey(key);
      final encodedKey = encodeKey(key);
      final targetFilePath = joinPath(_storagePath, '$encodedKey.val');
      final file = File(targetFilePath);
      final lock = _getKeyLock(_storagePath, encodedKey);

      return lock.synchronized(() {
        try {
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (e) {
          throw StorageIOException(
            'Failed to remove storage key: $key',
            operation: 'remove',
            targetKey: key,
            targetPath: targetFilePath,
            cause: e,
          );
        }
      });
    } catch (e, st) {
      return Future.error(e, st);
    }
  }

  @override
  Future<void> clear() {
    final lock = _getDirLock(_storagePath);
    return lock.synchronized(() {
      final dir = Directory(_storagePath);
      try {
        if (!dir.existsSync()) {
          return;
        }
      } catch (e) {
        throw StorageIOException(
          'Failed to check storage directory for clear: $_storagePath',
          operation: 'clear',
          targetPath: _storagePath,
          cause: e,
        );
      }

      try {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final name = getBasename(entity.path);
            if (name.endsWith('.val') || name.contains('.tmp.')) {
              try {
                entity.deleteSync();
              } catch (e) {
                throw StorageIOException(
                  'Failed to delete storage file during clear: ${entity.path}',
                  operation: 'clear',
                  targetPath: entity.path,
                  cause: e,
                );
              }
            }
          }
        }
      } catch (e) {
        if (e is StorageIOException) rethrow;
        throw StorageIOException(
          'Failed to list or clear storage directory: $_storagePath',
          operation: 'clear',
          targetPath: _storagePath,
          cause: e,
        );
      }
    });
  }

  /// Removes any dangling temporary files (*.tmp.*) left by previous interrupted processes.
  Future<int> cleanDanglingTempFiles() async {
    final dir = Directory(_storagePath);
    if (!dir.existsSync()) return 0;

    int cleaned = 0;
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final name = getBasename(entity.path);
          if (name.contains('.tmp.')) {
            try {
              entity.deleteSync();
              cleaned++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return cleaned;
  }
}
