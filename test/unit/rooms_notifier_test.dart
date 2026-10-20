import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/room.dart';
import 'package:lumivo/features/rooms/state/rooms_notifier.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/storage_adapter_stub.dart';

void main() {
  group('RoomsNotifier Unit Tests', () {
    late StorageAdapterImpl storage;
    late HomePersistenceManager persistence;
    late RoomsNotifier notifier;

    setUp(() async {
      storage = StorageAdapterImpl();
      persistence = HomePersistenceManager(storage: storage);
      await persistence.saveRooms([
        const Room(id: 'r1', name: 'Living Room'),
        const Room(id: 'r2', name: 'Bedroom'),
      ]);
      notifier = RoomsNotifier(
        persistence.cachedState!.rooms,
        persistence,
      );
    });

    test('initial state contains given rooms', () {
      expect(notifier.state.length, 2);
      expect(notifier.state[0].name, 'Living Room');
      expect(notifier.state[1].name, 'Bedroom');
    });

    test('addRoom adds a new room and persists', () async {
      await notifier.addRoom(
        const Room(
          id: 'r3',
          name: 'Balcony',
          iconName: 'balcony',
          description: 'Outdoor area',
        ),
      );

      expect(notifier.state.length, 3);
      expect(notifier.state.any((r) => r.id == 'r3'), isTrue);

      final loaded = await persistence.loadHomeState();
      expect(loaded.rooms.any((r) => r.id == 'r3'), isTrue);
    });

    test('addRoom replaces room if ID already exists', () async {
      await notifier.addRoom(
        const Room(
          id: 'r1',
          name: 'Main Living Room',
          iconName: 'living_room',
        ),
      );

      expect(notifier.state.length, 2);
      expect(notifier.state.firstWhere((r) => r.id == 'r1').name,
          'Main Living Room');
    });

    test('updateRoom updates existing room', () async {
      await notifier.updateRoom(
        const Room(
          id: 'r2',
          name: 'Guest Bedroom',
          iconName: 'bed',
        ),
      );

      expect(
        notifier.state.firstWhere((r) => r.id == 'r2').name,
        'Guest Bedroom',
      );
    });

    test('deleteRoom removes room with specified id', () async {
      await notifier.deleteRoom('r1');

      expect(notifier.state.length, 1);
      expect(notifier.state.any((r) => r.id == 'r1'), isFalse);

      final loaded = await persistence.loadHomeState();
      expect(loaded.rooms.any((r) => r.id == 'r1'), isFalse);
    });

    test('setRooms sets list of rooms', () async {
      await notifier.setRooms([
        const Room(id: 'office', name: 'Home Office'),
      ]);

      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, 'office');
    });
  });
}
