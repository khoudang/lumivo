import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/activity_event.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter.dart';
import 'package:lumivo/services/storage/storage_adapter_factory.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

class FailingMockStorageAdapter implements StorageAdapter {
  FailingMockStorageAdapter({this.failWithQuota = false, this.failAlways = false});

  bool failWithQuota;
  bool failAlways;
  final Map<String, String> data = {};

  @override
  Future<String?> getString(String key) async => data[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failAlways) {
      throw Exception('Simulated I/O disk failure on write');
    }
    if (failWithQuota) {
      failWithQuota = false; // Allow subsequent retry to succeed
      throw Exception('QuotaExceededError: LocalStorage limit reached');
    }
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }

  @override
  Future<void> clear() async {
    data.clear();
  }
}

void main() {
  group('Phase 11 Durable Native Storage Regression Tests', () {
    tearDown(() async {
      StorageAdapterFactory.setMockAdapter(null);
      final adapter = StorageAdapterFactory.create();
      await adapter.remove('independent-qa-key');
      await adapter.remove('independent-qa-recreate');
    });

    test('CONTROL: native storage reads its own write', () async {
      StorageAdapterFactory.setMockAdapter(null);
      final adapter = StorageAdapterFactory.create();
      await adapter.setString('independent-qa-key', 'saved-value');
      expect(await adapter.getString('independent-qa-key'), 'saved-value');
    });

    test('REGRESSION: native persistent storage must survive adapter recreation', () async {
      StorageAdapterFactory.setMockAdapter(null);
      final first = StorageAdapterFactory.create();
      await first.setString('independent-qa-recreate', 'saved-value');
      final second = StorageAdapterFactory.create();
      expect(await second.getString('independent-qa-recreate'), 'saved-value',
          reason: 'Actual native factory selects per-instance RAM, not disk storage.');
    });

    test('StorageAdapterFactory precedence preserves mock adapter without disk write', () async {
      final mock = StorageAdapterImpl();
      StorageAdapterFactory.setMockAdapter(mock);
      final created = StorageAdapterFactory.create();
      expect(identical(created, mock), isTrue);
      await created.setString('mock-key', 'mock-val');
      expect(await mock.getString('mock-key'), 'mock-val');

      // Native disk storage should not have 'mock-key'
      StorageAdapterFactory.setMockAdapter(null);
      final native = StorageAdapterFactory.create();
      expect(await native.getString('mock-key'), isNull);
    });

    test('Honest commit semantics: cached state is NOT committed if storage write throws', () async {
      final mock = FailingMockStorageAdapter(failAlways: true);
      final manager = HomePersistenceManager(storage: mock);

      final initial = manager.cachedState!;
      final candidate = initial.copyWith(currentHomeId: 'candidate-uncommitted-home');

      // Attempt to save should fail and must NOT mutate _cachedState
      expect(() => manager.saveHomeState(candidate), throwsA(isA<Exception>()));
      expect(manager.cachedState?.currentHomeId, initial.currentHomeId,
          reason: 'Honest commit semantics require cachedState to remain unchanged when write fails.');
    });

    test('Honest commit semantics: quota error prunes and commits pruned state on retry success', () async {
      final mock = FailingMockStorageAdapter(failWithQuota: true);
      final manager = HomePersistenceManager(storage: mock);

      final lotsOfEvents = List<ActivityEvent>.generate(
        30,
        (i) => ActivityEvent(
          id: 'evt-$i',
          deviceId: 'dev-1',
          title: 'Event $i',
          description: 'Description $i',
          timestamp: DateTime.now(),
        ),
      );
      final heavyState = manager.createDemoState().copyWith(activityEvents: lotsOfEvents);

      await manager.saveHomeState(heavyState);

      expect(manager.cachedState, isNotNull);
      expect(manager.cachedState!.activityEvents.length, 10,
          reason: 'Quota retry must prune historical collections to 10 entries and honest commit cachedState.');
    });
  });
}
