import 'dart:convert';
import 'dart:io';
import 'storage_adapter.dart';

String resolveAppStoragePath() {
  if (Platform.isWindows) {
    final appData =
        Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return '$appData/Lumivo/storage';
    }
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/Library/Application Support/Lumivo/storage';
    }
  } else if (Platform.isLinux) {
    final xdg = Platform.environment['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return '$xdg/lumivo/storage';
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/.local/share/lumivo/storage';
    }
  }
  final fallbackUser =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
  return '$fallbackUser/.lumivo/storage';
}

/// Durable file-backed storage adapter for native platforms.
class DurableStorageAdapter implements StorageAdapter {
  DurableStorageAdapter({String? storagePath})
      : _storagePath = storagePath ?? resolveAppStoragePath();

  final String _storagePath;

  String _keyToFileName(String key) {
    final bytes = utf8.encode(key);
    final encoded = base64Url.encode(bytes).replaceAll('=', '');
    return '$encoded.val';
  }

  @override
  Future<String?> getString(String key) async {
    final file = File('$_storagePath/${_keyToFileName(key)}');
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
    final dir = Directory(_storagePath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final targetPath = '$_storagePath/${_keyToFileName(key)}';
    final tmpPath =
        '$_storagePath/${_keyToFileName(key)}.${DateTime.now().microsecondsSinceEpoch}.tmp';
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
    final file = File('$_storagePath/${_keyToFileName(key)}');
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    final dir = Directory(_storagePath);
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

StorageAdapter createStorageAdapter() => DurableStorageAdapter();
