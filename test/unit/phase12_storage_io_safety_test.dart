import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/services/storage/durable_storage_backend.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_exceptions.dart';

String _resolveDartExecutable() {
  final current = Platform.resolvedExecutable;
  if (current.toLowerCase().contains('dart') &&
      !current.toLowerCase().contains('flutter_tester')) {
    return current;
  }
  // When running inside flutter_tester, resolve dart from Flutter SDK cache
  final engineDir = DurableStorageBackend.getDirname(current);
  final dartSdkCandidate = File(
    DurableStorageBackend.joinPath(
      engineDir,
      '../../dart-sdk/bin/${Platform.isWindows ? "dart.exe" : "dart"}',
    ),
  ).absolute.path;
  if (File(dartSdkCandidate).existsSync()) {
    return dartSdkCandidate;
  }
  return Platform.isWindows ? 'dart.bat' : 'dart';
}

void main() {
  late Directory testDir;

  setUp(() {
    testDir = Directory.systemTemp.createTempSync('lumivo_phase12_test_');
  });

  tearDown(() {
    if (testDir.existsSync()) {
      try {
        testDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Requirement 1: Atomic staging, rename safety, temp naming, failure cleanup', () {
    test('Temp file staging uses <encoded_key>.tmp.<pid>_<counter>_<time> in the same directory', () async {
      final backend = DurableStorageBackend(storagePath: testDir.path);
      String? observedTempPath;

      await backend.setString(
        'test-key',
        'staged-content',
        onStaged: (tempFile) {
          observedTempPath = tempFile.path;
          expect(tempFile.existsSync(), isTrue);
          expect(tempFile.readAsStringSync(), 'staged-content');
        },
      );

      expect(observedTempPath, isNotNull);
      final fileName = DurableStorageBackend.getBasename(observedTempPath!);
      final encodedKey = DurableStorageBackend.encodeKey('test-key');

      // Pattern: <encoded_key>.tmp.<pid>_<counter>_<time>
      final tempPattern = RegExp('^$encodedKey\\.tmp\\.\\d+_\\d+_\\d+\$');
      expect(tempPattern.hasMatch(fileName), isTrue,
          reason: 'Temp file name ($fileName) must match <encoded_key>.tmp.<pid>_<counter>_<time>');
      expect(
        DurableStorageBackend.getDirname(observedTempPath!),
        testDir.path,
        reason: 'Temp file must be staged in the same directory as storagePath',
      );

      // After commit, target file exists and temp file is cleaned up
      final committedFile = File(
        DurableStorageBackend.joinPath(testDir.path, '$encodedKey.val'),
      );
      expect(committedFile.existsSync(), isTrue);
      expect(committedFile.readAsStringSync(), 'staged-content');
      expect(File(observedTempPath!).existsSync(), isFalse,
          reason: 'Temp file must be removed after successful rename');
    });

    test('Never delete or truncate old committed value when atomic replace fails', () async {
      final backend = DurableStorageBackend(storagePath: testDir.path);

      // Commit initial stable value
      await backend.setString('important-key', 'ORIGINAL_COMMITTED_VALUE');
      expect(await backend.getString('important-key'), 'ORIGINAL_COMMITTED_VALUE');

      final encodedKey = DurableStorageBackend.encodeKey('important-key');
      final committedFile = File(
        DurableStorageBackend.joinPath(testDir.path, '$encodedKey.val'),
      );

      // Simulate a platform failure during rename/commit by throwing from onStaged hook
      await expectLater(
        () => backend.setString(
          'important-key',
          'CORRUPTED_NEW_VALUE',
          onStaged: (tempFile) {
            throw const FileSystemException('Simulated disk/permission failure during atomic commit');
          },
        ),
        throwsA(isA<StorageIOException>()),
      );

      // Verify the old committed value is completely untouched and NOT deleted or truncated
      expect(committedFile.existsSync(), isTrue);
      expect(committedFile.readAsStringSync(), 'ORIGINAL_COMMITTED_VALUE');
      expect(await backend.getString('important-key'), 'ORIGINAL_COMMITTED_VALUE');

      // Verify owned temp files were cleaned up
      final remainingTempFiles = testDir
          .listSync()
          .where((e) => DurableStorageBackend.getBasename(e.path).contains('.tmp.'))
          .toList();
      expect(remainingTempFiles, isEmpty, reason: 'Owned temp files must be cleaned up on failure');
    });

    test('Clean owned temp files on failure without hiding original exception', () async {
      final backend = DurableStorageBackend(storagePath: testDir.path);

      Object? caughtException;
      try {
        await backend.setString(
          'failing-key',
          'should-fail',
          onStaged: (tempFile) {
            throw const FileSystemException('Target filesystem is full');
          },
        );
      } catch (e) {
        caughtException = e;
      }

      expect(caughtException, isA<StorageIOException>());
      final ioEx = caughtException as StorageIOException;
      expect(ioEx.cause, isNotNull);
      expect(ioEx.cause.toString(), contains('Target filesystem is full'),
          reason: 'Original exception must not be hidden');

      // Check no temp files are leaked
      final remainingTempFiles = testDir
          .listSync()
          .where((e) => DurableStorageBackend.getBasename(e.path).contains('.tmp.'))
          .toList();
      expect(remainingTempFiles, isEmpty);
    });
  });

  group('Requirement 2: Error handling, missing keys, honest cache, selective clear', () {
    test('Genuinely missing key returns null', () async {
      final backend = DurableStorageBackend(storagePath: testDir.path);
      final val = await backend.getString('non-existent-key-12345');
      expect(val, isNull);
    });

    test('Permission or I/O errors on reading are NOT turned into success/empty state', () async {
      final backend = DurableStorageBackend(storagePath: testDir.path);

      // Create a directory where the file was expected: reading this path will fail
      final invalidDirKey = 'dir-conflict-key';
      final invalidDirEncoded = DurableStorageBackend.encodeKey(invalidDirKey);
      Directory(
        DurableStorageBackend.joinPath(testDir.path, '$invalidDirEncoded.val'),
      ).createSync();

      expect(
        () => backend.getString(invalidDirKey),
        throwsA(isA<StorageIOException>()),
        reason: 'Read error must throw StorageIOException and never return null or empty string',
      );
    });

    test('Clear must delete ONLY *.val and *.tmp* matching Lumivo pattern, not unrelated files', () async {
      final backend = DurableStorageBackend(storagePath: testDir.path);

      // Create Lumivo files
      await backend.setString('lumivo-key-1', 'val-1');
      await backend.setString('lumivo-key-2', 'val-2');

      // Create an orphaned temp file matching Lumivo pattern
      final orphanedTemp = File(
        DurableStorageBackend.joinPath(testDir.path, 'bHVtaXZv.tmp.999_1_123456789'),
      );
      orphanedTemp.writeAsStringSync('dangling-temp');

      // Create unrelated files and folders
      final unrelatedTxt = File(
        DurableStorageBackend.joinPath(testDir.path, 'unrelated.txt'),
      )..writeAsStringSync('keep me');
      final configJson = File(
        DurableStorageBackend.joinPath(testDir.path, 'config.json'),
      )..writeAsStringSync('{"keep": true}');
      final backupVal = File(
        DurableStorageBackend.joinPath(testDir.path, 'system.val.bak'),
      )..writeAsStringSync('backup file');
      final subDir = Directory(
        DurableStorageBackend.joinPath(testDir.path, 'subfolder'),
      )..createSync();
      final subFile = File(
        DurableStorageBackend.joinPath(subDir.path, 'child.txt'),
      )..writeAsStringSync('child');

      // Perform clear
      await backend.clear();

      // Verify Lumivo files are deleted
      expect(await backend.getString('lumivo-key-1'), isNull);
      expect(await backend.getString('lumivo-key-2'), isNull);
      expect(orphanedTemp.existsSync(), isFalse, reason: 'Matching temp files must be deleted by clear');

      // Verify unrelated files are PRESERVED
      expect(unrelatedTxt.existsSync(), isTrue, reason: 'unrelated.txt must NOT be deleted');
      expect(configJson.existsSync(), isTrue, reason: 'config.json must NOT be deleted');
      expect(backupVal.existsSync(), isTrue, reason: 'system.val.bak must NOT be deleted');
      expect(subDir.existsSync(), isTrue, reason: 'subfolder must NOT be deleted');
      expect(subFile.existsSync(), isTrue, reason: 'subfolder/child.txt must NOT be deleted');
    });

    test('Manager cache and lastSaved do NOT claim commit when durable write fails', () async {
      // Create a storage directory that points to a non-creatable path (file-as-dir)
      final dummyFile = File(
        DurableStorageBackend.joinPath(testDir.path, 'file_blocking_dir'),
      )..writeAsStringSync('block');
      final failingBackend = DurableStorageBackend(
        storagePath: DurableStorageBackend.joinPath(dummyFile.path, 'sub'),
      );

      final manager = HomePersistenceManager(storage: failingBackend);
      final initialCached = manager.cachedState;
      final initialLastSaved = manager.lastSavedAt;

      final newState = manager.createDemoState().copyWith(currentHomeId: 'failed-uncommitted-home');

      await expectLater(
        () => manager.saveHomeState(newState),
        throwsA(isA<StorageException>()),
      );

      // Verify cachedState is unchanged and lastSavedAt is not updated to claim commit
      expect(manager.cachedState?.currentHomeId, isNot(equals('failed-uncommitted-home')));
      expect(manager.cachedState?.currentHomeId, equals(initialCached?.currentHomeId));
      expect(manager.lastSavedAt, equals(initialLastSaved),
          reason: 'lastSavedAt must not claim commit when write fails');
    });
  });

  group('Requirement 3: Concurrency synchronization & honest limits', () {
    test('Concurrent writers on the same key do NOT produce partial content or temp collisions', () async {
      final backend = DurableStorageBackend(storagePath: testDir.path);
      const key = 'race-condition-key';
      const iterations = 25;

      // Launch 25 concurrent setString calls with distinct long payloads
      final futures = <Future<void>>[];
      for (var i = 0; i < iterations; i++) {
        final payload = 'PAYLOAD_${i}_${'X' * 5000}_END_$i';
        futures.add(backend.setString(key, payload));
      }

      await Future.wait(futures);

      // The final state must be a complete payload, not corrupted or torn
      final result = await backend.getString(key);
      expect(result, isNotNull);
      expect(result!, startsWith('PAYLOAD_'));
      final id = result.split('_')[1];
      expect(result, endsWith('_END_$id'));
      expect(result.length, 'PAYLOAD_${id}_${'X' * 5000}_END_$id'.length);

      // No leftover temp files
      final tempFiles = testDir.listSync().where(
        (e) => DurableStorageBackend.getBasename(e.path).contains('.tmp.'),
      );
      expect(tempFiles, isEmpty);
    });

    test('Concurrent writers across multiple backend instances share in-process key lock', () async {
      final backendA = DurableStorageBackend(storagePath: testDir.path);
      final backendB = DurableStorageBackend(storagePath: testDir.path);
      const key = 'cross-instance-key';

      final writes = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        final backend = i.isEven ? backendA : backendB;
        writes.add(backend.setString(key, 'VALUE_$i'));
      }

      await Future.wait(writes);

      final finalValue = await backendA.getString(key);
      expect(finalValue, isNotNull);
      expect(finalValue, startsWith('VALUE_'));
    });

    test('Multi-process limits are defined and documented honestly', () {
      expect(DurableStorageBackend.durabilityNotice, isNotEmpty);
      expect(DurableStorageBackend.durabilityNotice, contains('Multi-process'));
      expect(DurableStorageBackend.durabilityNotice, contains('last-write-wins'));
    });
  });

  group('Requirement 4: Child-Process Termination Probe', () {
    test('Child process killed during staging leaves original committed value intact', () async {
      final probePath = File(
        DurableStorageBackend.joinPath(
          Directory.current.path,
          'test/tool/child_process_probe.dart',
        ),
      ).absolute.path;
      expect(File(probePath).existsSync(), isTrue, reason: 'child_process_probe.dart must exist');

      final backend = DurableStorageBackend(storagePath: testDir.path);
      const testKey = 'probe-safety-key';
      const initialValue = 'STABLE_COMMITTED_PRE_KILL_VALUE';
      const interruptingValue = 'CORRUPTED_INCOMPLETE_POST_KILL_VALUE';

      // 1. Write initial committed value
      await backend.setString(testKey, initialValue);
      expect(await backend.getString(testKey), initialValue);

      final encodedKey = DurableStorageBackend.encodeKey(testKey);
      final committedFile = File(
        DurableStorageBackend.joinPath(testDir.path, '$encodedKey.val'),
      );
      expect(committedFile.existsSync(), isTrue);
      expect(committedFile.readAsStringSync(), initialValue);

      // 2. Start child process that stages new value and pauses before commit
      final dartExe = _resolveDartExecutable();
      final process = await Process.start(
        dartExe,
        [
          'run',
          probePath,
          'stage-and-pause',
          testDir.path,
          testKey,
          interruptingValue,
        ],
      );

      final stdoutCompleter = Completer<String>();
      final lines = <String>[];

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        lines.add(line);
        final trimmed = line.trim();
        final matchIdx = trimmed.indexOf('STAGED:');
        if (matchIdx != -1 && !stdoutCompleter.isCompleted) {
          final stagedPath = trimmed.substring(matchIdx + 'STAGED:'.length).trim();
          stdoutCompleter.complete(stagedPath);
        }
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((err) {
        lines.add('STDERR: $err');
      });

      // Wait until child process reports that it has staged the temp file
      final stagedFilePath = await stdoutCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Probe did not reach STAGED in time. Output: $lines'),
      );

      // 3. Inspect filesystem BEFORE killing child process:
      // Temp file exists with interrupting content
      final stagedFile = File(stagedFilePath);
      expect(stagedFile.existsSync(), isTrue, reason: 'Staged temp file must exist before kill');
      expect(stagedFile.readAsStringSync(), interruptingValue);

      // Old committed file MUST STILL EXIST and contain the old intact value!
      expect(committedFile.existsSync(), isTrue, reason: 'Old committed file must still exist during staging');
      expect(committedFile.readAsStringSync(), initialValue,
          reason: 'Old committed file must not be modified or truncated during staging');

      // 4. Forcibly terminate the child process (simulating process crash / SIGKILL)
      process.kill();
      await process.exitCode;

      // 5. Inspect filesystem AFTER child process termination:
      // The old committed file MUST STILL BE 100% INTACT!
      expect(committedFile.existsSync(), isTrue, reason: 'Committed file must survive child process crash');
      expect(committedFile.readAsStringSync(), initialValue,
          reason: 'Committed file content must remain original value after child process crash');
      expect(await backend.getString(testKey), initialValue,
          reason: 'Backend get must return intact original value');

      // Clean up orphaned temp files left by the killed process
      final cleanedCount = await backend.cleanDanglingTempFiles();
      expect(cleanedCount, greaterThanOrEqualTo(1));
      expect(stagedFile.existsSync(), isFalse);
      expect(await backend.getString(testKey), initialValue);
    });
  });
}
