import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/home.dart';
import 'package:lumivo/services/home/home_service.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('HomeService Unit Tests', () {
    late HomeService service;
    late StorageAdapterImpl storage;

    setUp(() {
      storage = StorageAdapterImpl();
      service = HomeService(storage: storage);
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial homes and current home retrieval', () {
      final homes = service.getHomes();
      expect(homes.length, equals(2));

      final current = service.getCurrentHome();
      expect(current.id, equals('home-default'));
      expect(current.name, equals('Lumivo Smart Villa'));
      expect(current.isCurrent, isTrue);
      expect(current.tariffRate, equals(0.16));
    });

    test('Custom initial homes list handles current selection', () {
      const h1 = Home(id: 'h1', name: 'Home 1', isCurrent: false);
      const h2 = Home(id: 'h2', name: 'Home 2', isCurrent: true);
      final customService = HomeService(initialHomes: [h1, h2]);

      expect(customService.getCurrentHome().id, equals('h2'));
      expect(customService.getHomes().length, equals(2));
      customService.dispose();
    });

    test('createHome creates a new home and updates homes list', () async {
      final emittedHomes = <List<Home>>[];
      service.homesStream.listen(emittedHomes.add);

      final newHome = await service.createHome(
        'Mountain Cabin',
        address: '500 Pine Peak Rd',
        tariffRate: 0.18,
        currency: 'USD',
      );

      expect(newHome.name, equals('Mountain Cabin'));
      expect(newHome.address, equals('500 Pine Peak Rd'));
      expect(newHome.tariffRate, equals(0.18));
      expect(newHome.currency, equals('USD'));
      expect(newHome.isCurrent, isFalse);

      final homes = service.getHomes();
      expect(homes.length, equals(3));
      expect(homes.any((h) => h.id == newHome.id), isTrue);

      await pumpEventQueue();
      expect(emittedHomes.isNotEmpty, isTrue);
      expect(emittedHomes.last.length, equals(3));
    });

    test('switchHome switches active home and emits on currentHomeStream',
        () async {
      final emittedCurrent = <Home>[];
      service.currentHomeStream.listen(emittedCurrent.add);

      expect(service.getCurrentHome().id, equals('home-default'));

      service.switchHome('home-vacation');

      final current = service.getCurrentHome();
      expect(current.id, equals('home-vacation'));
      expect(current.name, equals('Seaside Retreat'));
      expect(current.isCurrent, isTrue);

      // Verify previous home is no longer current
      final defaultHome =
          service.getHomes().firstWhere((h) => h.id == 'home-default');
      expect(defaultHome.isCurrent, isFalse);

      await pumpEventQueue();
      expect(emittedCurrent.length, equals(1));
      expect(emittedCurrent.first.id, equals('home-vacation'));
    });

    test('switchHome throws ArgumentError on unknown homeId', () {
      expect(
        () => service.switchHome('unknown-id'),
        throwsArgumentError,
      );
    });

    test('switchHome to already active home is a no-op', () async {
      final emittedCurrent = <Home>[];
      service.currentHomeStream.listen(emittedCurrent.add);

      service.switchHome('home-default'); // Already active

      await pumpEventQueue();
      expect(emittedCurrent.isEmpty, isTrue);
    });

    test('updateHome updates existing home fields and handles current state',
        () async {
      final current = service.getCurrentHome();
      final updated = current.copyWith(
        name: 'Lumivo Grand Villa',
        tariffRate: 0.19,
      );

      await service.updateHome(updated);

      final retrieved = service.getCurrentHome();
      expect(retrieved.name, equals('Lumivo Grand Villa'));
      expect(retrieved.tariffRate, equals(0.19));

      expect(
        () => service.updateHome(const Home(id: 'non-existent', name: 'Ghost')),
        throwsArgumentError,
      );
    });

    test('deleteHome non-current home removes safely without changing current',
        () async {
      final emittedCurrent = <Home>[];
      service.currentHomeStream.listen(emittedCurrent.add);

      await service.deleteHome('home-vacation');

      expect(service.getHomes().length, equals(1));
      expect(service.getCurrentHome().id, equals('home-default'));

      await pumpEventQueue();
      expect(emittedCurrent.isEmpty, isTrue);
    });

    test('deleteHome current home automatically switches to fallback home',
        () async {
      final emittedCurrent = <Home>[];
      service.currentHomeStream.listen(emittedCurrent.add);

      // Default home is currently active; deleting it should fallback to home-vacation
      await service.deleteHome('home-default');

      final current = service.getCurrentHome();
      expect(current.id, equals('home-vacation'));
      expect(current.isCurrent, isTrue);
      expect(service.getHomes().length, equals(1));

      await pumpEventQueue();
      expect(emittedCurrent.length, equals(1));
      expect(emittedCurrent.first.id, equals('home-vacation'));
    });

    test('deleteHome when all homes deleted regenerates default home safely',
        () async {
      await service.deleteHome('home-vacation');
      await service.deleteHome('home-default');

      final current = service.getCurrentHome();
      expect(current.id, equals('home-default'));
      expect(service.getHomes().isNotEmpty, isTrue);
    });

    test('persistence storage saves JSON state on modifications', () async {
      expect(await storage.getString(DefaultHomeService.storageKey), isNull);

      await service.createHome('Lake House');
      final raw = await storage.getString(DefaultHomeService.storageKey);
      expect(raw, isNotNull);
      expect(raw!.contains('Lake House'), isTrue);
    });
  });
}
