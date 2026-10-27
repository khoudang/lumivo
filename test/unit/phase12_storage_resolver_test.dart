import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/services/storage/platform_storage_resolver.dart';
import 'package:lumivo/services/storage/storage_adapter_factory.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';
import 'package:lumivo/services/storage/storage_exceptions.dart';

void main() {
  group('Phase 12 PlatformStorageResolver Contract Tests', () {
    setUp(() {
      PlatformStorageResolver.reset();
      StorageAdapterFactory.reset();
    });

    tearDown(() {
      PlatformStorageResolver.reset();
      StorageAdapterFactory.reset();
    });

    group('a) Custom resolver injection (Priority 1)', () {
      test('synchronous custom resolver is prioritized over env and platform', () async {
        PlatformStorageResolver.setCustomResolver(() => '/custom/injected/storage');
        PlatformStorageResolver.setEnvironmentOverride({
          'LUMIVO_STORAGE_DIR': '/env/storage/dir',
          'APPDATA': r'C:\MockAppData',
        });

        final resolved = await PlatformStorageResolver.resolve();
        expect(resolved, '/custom/injected/storage');
      });

      test('asynchronous custom resolver is respected', () async {
        PlatformStorageResolver.setCustomResolver(() async => '/async/custom/storage');
        PlatformStorageResolver.setEnvironmentOverride({
          'LUMIVO_STORAGE_DIR': '/env/storage/dir',
        });

        final resolved = await PlatformStorageResolver.resolve();
        expect(resolved, '/async/custom/storage');
      });

      test('custom resolver passed directly in resolve() takes precedence', () async {
        final resolved = await PlatformStorageResolver.resolve(
          customResolver: () => '/direct/injected/path',
          environment: {'LUMIVO_STORAGE_DIR': '/env/dir'},
        );
        expect(resolved, '/direct/injected/path');
      });

      test('null or empty custom resolver falls through to next priority', () async {
        PlatformStorageResolver.setCustomResolver(() => null);
        PlatformStorageResolver.setEnvironmentOverride({
          'LUMIVO_STORAGE_DIR': '/env/fallback/dir',
        });

        final resolved = await PlatformStorageResolver.resolve();
        expect(resolved, '/env/fallback/dir');
      });
    });

    group('b) LUMIVO_STORAGE_DIR environment variable resolution (Priority 2)', () {
      test('resolves LUMIVO_STORAGE_DIR when no custom resolver is set', () async {
        PlatformStorageResolver.setEnvironmentOverride({
          'LUMIVO_STORAGE_DIR': '/sandbox/test_lumivo_storage',
          'APPDATA': r'C:\AppData\ShouldNotUse',
        });

        final resolved = await PlatformStorageResolver.resolve();
        expect(resolved, '/sandbox/test_lumivo_storage');
      });

      test('passed environment map is respected', () async {
        final resolved = await PlatformStorageResolver.resolve(
          environment: {'LUMIVO_STORAGE_DIR': '/harness/isolated_dir'},
        );
        expect(resolved, '/harness/isolated_dir');
      });

      test('trims whitespace and ignores empty LUMIVO_STORAGE_DIR', () async {
        PlatformStorageResolver.setEnvironmentOverride({
          'LUMIVO_STORAGE_DIR': '   ',
          'APPDATA': r'C:\FallbackAppData',
        });
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.windows);

        final resolved = await PlatformStorageResolver.resolve();
        expect(resolved, r'C:\FallbackAppData/Lumivo/storage');
      });
    });

    group('c) Mobile path resolution via path_provider without hardcoding (Priority 3)', () {
      test('Android resolves app support directory dynamically via path_provider', () async {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.android);
        PlatformStorageResolver.setEnvironmentOverride({});
        PlatformStorageResolver.setApplicationSupportDirectoryProvider(
          () async => Directory('/data/user/0/com.enterprise.iot.lumivo/files'),
        );

        final resolved = await PlatformStorageResolver.resolve();
        expect(resolved, '/data/user/0/com.enterprise.iot.lumivo/files/storage');
        expect(resolved.contains('com.lumivo.app'), isFalse,
            reason: 'Must NOT hardcode com.lumivo.app package name.');
      });

      test('iOS resolves app support directory dynamically without hardcoded bundle ID', () async {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.iOS);
        PlatformStorageResolver.setEnvironmentOverride({});
        PlatformStorageResolver.setApplicationSupportDirectoryProvider(
          () async => Directory('/var/mobile/Containers/Data/Application/12345-GUID/Library/Application Support'),
        );

        final resolved = await PlatformStorageResolver.resolve();
        expect(
          resolved,
          '/var/mobile/Containers/Data/Application/12345-GUID/Library/Application Support/storage',
        );
        expect(resolved.contains('com.lumivo.app'), isFalse);
      });

      test('normalizes already existing /storage suffix without duplication', () async {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.android);
        PlatformStorageResolver.setEnvironmentOverride({});
        PlatformStorageResolver.setApplicationSupportDirectoryProvider(
          () async => Directory('/data/user/0/org.custom.app/storage'),
        );

        final resolved = await PlatformStorageResolver.resolve();
        expect(resolved, '/data/user/0/org.custom.app/storage');
      });
    });

    group('d) Explicit StoragePathException thrown when path is unresolvable', () {
      test('throws StoragePathException on Mobile if path_provider throws', () async {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.android);
        PlatformStorageResolver.setEnvironmentOverride({});
        PlatformStorageResolver.setApplicationSupportDirectoryProvider(
          () async => throw Exception('MissingPluginException(No implementation found for getApplicationSupportDirectory)'),
        );

        expect(
          () => PlatformStorageResolver.resolve(),
          throwsA(isA<StoragePathException>()),
        );
      });

      test('throws StoragePathException on Mobile when path_provider returns empty directory path', () async {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.iOS);
        PlatformStorageResolver.setEnvironmentOverride({});
        PlatformStorageResolver.setApplicationSupportDirectoryProvider(
          () async => Directory(''),
        );

        expect(
          () => PlatformStorageResolver.resolve(),
          throwsA(isA<StoragePathException>()),
        );
      });

      test('throws StoragePathException on Desktop if env vars missing and path_provider fails', () async {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.windows);
        PlatformStorageResolver.setEnvironmentOverride({});
        PlatformStorageResolver.setApplicationSupportDirectoryProvider(
          () async => throw Exception('path_provider unavailable on headless host'),
        );

        expect(
          () => PlatformStorageResolver.resolve(),
          throwsA(isA<StoragePathException>()),
        );
      });

      test('never falls back to CWD, RAM, or temp in production resolution', () async {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.android);
        PlatformStorageResolver.setEnvironmentOverride({});
        PlatformStorageResolver.setApplicationSupportDirectoryProvider(
          () async => throw const FileSystemException('Permission denied'),
        );

        try {
          final result = await PlatformStorageResolver.resolve();
          fail('Expected StoragePathException but returned: $result');
        } on StoragePathException catch (e) {
          expect(e.message, contains('Failed to resolve'));
          expect(e.toString(), contains('StoragePathException:'));
        }
      });

      test('resolveAppStoragePath throws StoragePathException when sync resolution fails', () {
        PlatformStorageResolver.setPlatformOverride(TargetPlatform.android);
        PlatformStorageResolver.setEnvironmentOverride({});

        expect(
          () => resolveAppStoragePath(),
          throwsA(isA<StoragePathException>()),
        );
      });
    });

    group('e) In-memory fixture safety & StorageAdapterFactory wiring', () {
      test('StorageAdapterImpl without storagePath operates in memory and does not write to disk', () async {
        final adapter = StorageAdapterImpl();
        expect(adapter.isInMemory, isTrue);

        await adapter.setString('transient-key', 'value-123');
        expect(await adapter.getString('transient-key'), 'value-123');

        // Isolation between in-memory instances
        final anotherAdapter = StorageAdapterImpl();
        expect(anotherAdapter.isInMemory, isTrue);
        expect(await anotherAdapter.getString('transient-key'), isNull);
      });

      test('StorageAdapterImpl with storagePath delegates to durable file storage', () async {
        final tempDir = Directory.systemTemp.createTempSync('lumivo_storage_test_');
        try {
          final adapter = StorageAdapterImpl(storagePath: tempDir.path);
          expect(adapter.isInMemory, isFalse);

          await adapter.setString('persistent-key', 'persistent-value');
          expect(await adapter.getString('persistent-key'), 'persistent-value');

          // New adapter pointing to same directory finds persisted file
          final second = StorageAdapterImpl(storagePath: tempDir.path);
          expect(await second.getString('persistent-key'), 'persistent-value');

          await adapter.clear();
          expect(await second.getString('persistent-key'), isNull);
        } finally {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });

      test('StorageAdapterFactory bootstrap and create wiring', () async {
        final tempDir = Directory.systemTemp.createTempSync('lumivo_factory_test_');
        try {
          await StorageAdapterFactory.bootstrap(storagePath: tempDir.path);
          final adapter = StorageAdapterFactory.create();

          await adapter.setString('factory-key', 'factory-val');
          expect(await adapter.getString('factory-key'), 'factory-val');

          // Precedence preserves mock adapter over bootstrap
          final mock = StorageAdapterImpl();
          StorageAdapterFactory.setMockAdapter(mock);
          final createdMock = StorageAdapterFactory.create();
          expect(identical(createdMock, mock), isTrue);
        } finally {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });
    });
  });
}
