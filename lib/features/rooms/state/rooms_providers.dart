import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/room.dart';

const List<Room> defaultRooms = [
  Room(id: 'room-1', name: 'Living Room', iconName: 'living_room'),
  Room(id: 'room-2', name: 'Bedroom', iconName: 'bedroom'),
  Room(id: 'room-3', name: 'Kitchen', iconName: 'kitchen'),
  Room(id: 'room-4', name: 'Office', iconName: 'office'),
  Room(id: 'room-5', name: 'Bathroom', iconName: 'bathroom'),
  Room(id: 'room-6', name: 'Balcony', iconName: 'balcony'),
];

class RoomsNotifier extends StateNotifier<List<Room>> {
  RoomsNotifier([List<Room>? initial]) : super(initial ?? defaultRooms);

  void addRoom(Room room) {
    if (!state.any((r) => r.name.toLowerCase() == room.name.toLowerCase())) {
      state = [...state, room];
    }
  }

  void removeRoom(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void reset() {
    state = defaultRooms;
  }
}

final roomsProvider = StateNotifierProvider<RoomsNotifier, List<Room>>((ref) {
  return RoomsNotifier();
});
