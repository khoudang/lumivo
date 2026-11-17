import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/services/storage/storage_adapter_native.dart';
import 'package:lumivo/services/storage/storage_adapter_factory.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart' as memory;
import 'package:lumivo/services/storage/native_storage_path_resolver.dart';

/// Real filesystem everywhere except deterministic denial of dangerous opens.
class _GuardedFile implements File {
  _GuardedFile(this.delegate, {this.denyRead = false});
  final File delegate;
  final bool denyRead;

  @override
  File get absolute => delegate.absolute;
  @override
  String get path => delegate.path;
  @override
  Directory get parent => delegate.parent;
  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    if (denyRead) {
      return Future.error(
          FileSystemException('Read denied', path, const OSError('Denied', 5)));
    }
    return delegate.readAsString(encoding: encoding);
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) =>
      Future.error(StateError('In-place writes are forbidden'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory sandbox;
  late File file;

  setUp(() async {
    // Hermes scratch is intentional: the host TMPDIR may still be system Temp.
    // Other CI hosts can opt into their own dedicated sandbox explicitly.
    final scratch = Platform.environment['LUMIVO_TEST_SCRATCH'] ??
        (Platform.isWindows
            ? '${Platform.environment['LOCALAPPDATA']}/hermes/cache/scratch'
            : '${Platform.environment['HOME']}/.cache/hermes/scratch');
    final root = await Directory(scratch).create(recursive: true);
    sandbox = await root.createTemp('lumivo-native-storage-');
    file = File('${sandbox.path}/nested/store.json');
  });
  tearDown(() async => sandbox.delete(recursive: true));

  test('factory uses explicit QA file while normal Flutter tests stay in RAM',
      () async {
    expect(StorageAdapterFactory.create(), isA<memory.StorageAdapterImpl>());
    await StorageAdapterFactory.create(storagePath: file.path)
        .setString('home', 'saved');
    expect(
        await StorageAdapterFactory.create(storagePath: file.path)
            .getString('home'),
        'saved');
    final injected = memory.StorageAdapterImpl();
    StorageAdapterFactory.setMockAdapter(injected);
    addTearDown(() => StorageAdapterFactory.setMockAdapter(null));
    expect(
        StorageAdapterFactory.create(storagePath: file.path), same(injected));
  });

  test('path resolution is pure, platform-specific and test-safe', () {
    String? resolve(String os, Map<String, String> env) =>
        NativeStoragePathResolver.resolve(
            operatingSystem: os, environment: env);
    expect(resolve('windows', {'LOCALAPPDATA': 'C:/Sandbox'}),
        'C:/Sandbox/Lumivo/storage.json');
    expect(resolve('windows', {'APPDATA': 'C:/Roaming'}),
        'C:/Roaming/Lumivo/storage.json');
    expect(resolve('macos', {'HOME': '/sandbox'}),
        '/sandbox/Library/Application Support/Lumivo/storage.json');
    expect(resolve('linux', {'HOME': '/sandbox'}),
        '/sandbox/.local/share/lumivo/storage.json');
    expect(resolve('linux', {'XDG_DATA_HOME': '/xdg'}),
        '/xdg/lumivo/storage.json');
    expect(
        resolve('windows',
            {'FLUTTER_TEST': 'true', 'LOCALAPPDATA': 'C:/NeverTouched'}),
        isNull);
    expect(
        resolve('windows', {
          'FLUTTER_TEST': 'true',
          'LUMIVO_STORAGE_PATH': 'C:/QA/store.json'
        }),
        'C:/QA/store.json');
    expect(resolve('windows', {'LUMIVO_STORAGE_DIR': 'C:/QA'}),
        'C:/QA/storage.json');
    expect(resolve('android', {'LUMIVO_STORAGE_PATH': '/qa/storage.json'}),
        '/qa/storage.json');
    expect(resolve('ios', {'LUMIVO_STORAGE_PATH': '/qa/storage.json'}),
        '/qa/storage.json');
    expect(() => resolve('windows', {}), throwsStateError);
    expect(() => resolve('linux', {'HOME': 'relative'}), throwsArgumentError);
    expect(resolve('android', {}), isNull);
    expect(resolve('ios', {}), isNull);
    expect(() => resolve('unknown-platform', {}), throwsUnsupportedError);
  });

  test('explicit QA storage survives distinct adapter instances', () async {
    await NativeStorageAdapter(file).setString('home', 'isolated fixture');
    expect(
        await NativeStorageAdapter(file).getString('home'), 'isolated fixture');
  });

  test('missing file reads as empty without creating a file', () async {
    expect(await NativeStorageAdapter(file).getString('missing'), isNull);
    expect(await file.exists(), isFalse);
  });

  test('remove and clear persist without affecting unrelated files', () async {
    final adapter = NativeStorageAdapter(file);
    await adapter.setString('one', '1');
    await adapter.setString('two', '2');
    final unrelated = File('${file.parent.path}/unrelated.txt');
    await unrelated.writeAsString('keep');
    await adapter.remove('one');
    expect(await NativeStorageAdapter(file).getString('one'), isNull);
    expect(await NativeStorageAdapter(file).getString('two'), '2');
    await adapter.clear();
    expect(jsonDecode(await file.readAsString()), isEmpty);
    expect(await unrelated.readAsString(), 'keep');
  });

  for (final source in [
    '{private-fixture',
    '[]',
    '{"key":42}',
    '{"key":null}'
  ]) {
    test('invalid store is non-destructive and errors redact contents: $source',
        () async {
      await file.parent.create(recursive: true);
      await file.writeAsString(source);
      final adapter = NativeStorageAdapter(file);
      final safeError = isA<FormatException>().having(
        (error) => error.toString(),
        'redacted diagnostic',
        isNot(contains('private-fixture')),
      );
      await expectLater(adapter.getString('key'), throwsA(safeError));
      await expectLater(adapter.setString('key', 'new'), throwsA(safeError));
      await expectLater(adapter.remove('key'), throwsA(safeError));
      await expectLater(adapter.clear(), throwsA(safeError));
      expect(await file.readAsString(), source);
      // Failure does not poison the queue: repair by external recovery only.
      await file.writeAsString('{"key":"recovered"}');
      expect(await adapter.getString('key'), 'recovered');
    });
  }

  test('access denied is not empty storage and cannot overwrite data',
      () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{"saved":"keep"}');
    final adapter = NativeStorageAdapter(_GuardedFile(file, denyRead: true));
    await expectLater(
        adapter.getString('saved'), throwsA(isA<FileSystemException>()));
    await expectLater(
        adapter.setString('new', 'no'), throwsA(isA<FileSystemException>()));
    await expectLater(
        adapter.remove('saved'), throwsA(isA<FileSystemException>()));
    await expectLater(adapter.clear(), throwsA(isA<FileSystemException>()));
    expect(await file.readAsString(), '{"saved":"keep"}');
  });

  test(
      'replacement stages content rather than opening committed file for write',
      () async {
    await NativeStorageAdapter(file).setString('saved', 'old');
    await NativeStorageAdapter(_GuardedFile(file)).setString('saved', 'new');
    expect(await NativeStorageAdapter(file).getString('saved'), 'new');
    expect(await file.parent.list().length, 1,
        reason: 'No owned staging files remain');
  });

  test('failed Windows replacement preserves old data and cleans staging',
      () async {
    if (!Platform.isWindows) return;
    await NativeStorageAdapter(file).setString('saved', 'keep');
    final marked = await Process.run('attrib', ['+R', file.path]);
    expect(marked.exitCode, 0);
    try {
      final adapter = NativeStorageAdapter(file);
      await expectLater(adapter.setString('saved', 'new'),
          throwsA(isA<FileSystemException>()));
      expect(await adapter.getString('saved'), 'keep');
      expect(await file.parent.list().length, 1);
    } finally {
      final restored = await Process.run('attrib', ['-R', file.path]);
      expect(restored.exitCode, 0);
    }
    await NativeStorageAdapter(file).setString('saved', 'retry');
    expect(await NativeStorageAdapter(file).getString('saved'), 'retry');
  });

  test('mixed queued mutations and reads observe invocation order', () async {
    final first = NativeStorageAdapter(file);
    final second = NativeStorageAdapter(file);
    final actions = <Future<void>>[
      first.setString('a', '1'),
      second.setString('b', '2'),
      first.remove('a'),
      second.clear(),
      first.setString('c', '3'),
    ];
    final read = second.getString('c');
    await Future.wait(actions);
    expect(await read, '3');
    expect(jsonDecode(await file.readAsString()), {'c': '3'});
  });

  test('directory at store path is a read failure, never empty storage',
      () async {
    await Directory(file.path).create(recursive: true);
    final marker = File('${file.path}/keep.txt');
    await marker.writeAsString('keep');
    final adapter = NativeStorageAdapter(file);
    await expectLater(
        adapter.getString('key'), throwsA(isA<FileSystemException>()));
    await expectLater(adapter.clear(), throwsA(isA<FileSystemException>()));
    expect(await marker.readAsString(), 'keep');
  });

  test('concurrent writes across instances do not lose keys', () async {
    await Future.wait([
      for (var index = 0; index < 20; index++)
        NativeStorageAdapter(file).setString('key$index', 'value$index'),
    ]);
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(saved.length, 20);
    for (var index = 0; index < 20; index++) {
      expect(saved['key$index'], 'value$index');
    }
  });
}
