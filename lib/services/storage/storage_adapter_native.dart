import 'dart:convert';
import 'dart:io';

import 'native_storage_path_resolver.dart';
import 'storage_adapter.dart';
import 'storage_adapter_stub.dart' as memory;

/// JSON-backed native storage. Supply a dedicated file for isolated QA runs.
///
/// Operations on the same normalized path are serialized within this isolate,
/// including reads. Independent isolates/processes must not write concurrently.
/// A flushed same-filesystem rename avoids in-place truncation; this is not a
/// promise of survival through hardware power loss or arbitrary network filesystems.
/// Symlink aliases are not coordinated. Values are not encrypted at rest.
class NativeStorageAdapter implements StorageAdapter {
  NativeStorageAdapter(this.file);

  final File file;
  static final Map<String, Future<void>> _queues = {};

  Future<T> _serialized<T>(Future<T> Function() action) {
    var path = file.absolute.uri.normalizePath().toFilePath();
    if (Platform.isWindows) path = path.toLowerCase();
    final previous = _queues[path] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _queues[path] = tail;
    tail.then((_) {
      if (identical(_queues[path], tail)) _queues.remove(path);
    });
    return result;
  }

  Future<Map<String, String>> _read() async {
    String content;
    try {
      content = await file.readAsString();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2 ||
          (Platform.isWindows && error.osError?.errorCode == 3)) {
        return {};
      }
      rethrow;
    }
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic> ||
          decoded.values.any((value) => value is! String)) {
        throw const FormatException('Invalid native storage format');
      }
      return Map<String, String>.from(decoded);
    } on FormatException {
      // Decoder diagnostics include source excerpts: never expose stored data.
      throw const FormatException('Invalid native storage format');
    }
  }

  @override
  Future<String?> getString(String key) =>
      _serialized(() async => (await _read())[key]);

  @override
  Future<void> setString(String key, String value) =>
      _mutate((values) => values[key] = value);

  @override
  Future<void> remove(String key) => _mutate((values) => values.remove(key));

  @override
  Future<void> clear() => _mutate((values) => values.clear());

  Future<void> _mutate(void Function(Map<String, String>) change) =>
      _serialized(() async {
        final values = await _read();
        change(values);
        await file.parent.create(recursive: true);
        // Stage on the same filesystem. Dart's rename replaces an existing file
        // on Windows too; never delete/move the old target before replacement.
        final staging = await file.parent.createTemp('.lumivo-write-');
        try {
          final pending = File('${staging.path}/pending.json');
          await pending.writeAsString(jsonEncode(values), flush: true);
          await pending.rename(file.path);
        } finally {
          // Cleanup must not turn a committed write into an apparent failure,
          // nor mask the original I/O failure. Only remove our own staging dir.
          try {
            await staging.delete(recursive: true);
          } on FileSystemException {
            // A leftover staging directory is never treated as committed data.
          }
        }
      });
}

StorageAdapter createStorageAdapter({String? storagePath}) {
  final path = NativeStoragePathResolver.resolve(
    storagePath: storagePath,
    operatingSystem: Platform.operatingSystem,
    environment: Platform.environment,
  );
  return path == null
      ? memory.StorageAdapterImpl()
      : NativeStorageAdapter(File(path));
}
