import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart' show devicesProvider;
import '../../../core/models/smart_device.dart';
import '../../home/state/homes_notifier.dart';

class DeviceSearchEngine {
  const DeviceSearchEngine._();

  static List<SmartDevice> search({
    required List<SmartDevice> devices,
    String query = '',
    DeviceType? typeFilter,
    bool? statusFilter,
    String sortBy = 'name',
  }) {
    final trimmedQuery = query.trim().toLowerCase();

    final filtered = devices.where((device) {
      if (trimmedQuery.isNotEmpty) {
        final matchesName = device.name.toLowerCase().contains(trimmedQuery);
        final matchesRoom = device.roomId.toLowerCase().contains(trimmedQuery);
        final matchesType =
            device.type.name.toLowerCase().contains(trimmedQuery);
        if (!matchesName && !matchesRoom && !matchesType) {
          return false;
        }
      }

      if (typeFilter != null && device.type != typeFilter) {
        return false;
      }

      if (statusFilter != null) {
        final isOnline = device.connection == DeviceConnection.online;
        if (isOnline != statusFilter) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (sortBy) {
        case 'room':
          final roomCmp =
              a.roomId.toLowerCase().compareTo(b.roomId.toLowerCase());
          if (roomCmp != 0) return roomCmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'recent':
          // Prioritize favorites and favoriteOrder, then id
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          final favOrderCmp = a.favoriteOrder.compareTo(b.favoriteOrder);
          if (favOrderCmp != 0) return favOrderCmp;
          return a.id.compareTo(b.id);
        case 'name':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return filtered;
  }
}

final deviceSearchQueryProvider = StateProvider<String>((ref) => '');

final deviceSearchTypeFilterProvider =
    StateProvider<DeviceType?>((ref) => null);

final deviceSearchStatusFilterProvider = StateProvider<bool?>((ref) => null);

final deviceSearchSortProvider = StateProvider<String>((ref) => 'name');

final filteredDevicesProvider = Provider<List<SmartDevice>>((ref) {
  final devicesAsync = ref.watch(devicesProvider);
  final currentHome = ref.watch(currentHomeProvider);
  final query = ref.watch(deviceSearchQueryProvider);
  final typeFilter = ref.watch(deviceSearchTypeFilterProvider);
  final statusFilter = ref.watch(deviceSearchStatusFilterProvider);
  final sortBy = ref.watch(deviceSearchSortProvider);

  final allDevices = devicesAsync.value ?? const [];
  final homeDevices =
      allDevices.where((d) => d.homeId == currentHome.id).toList();

  return DeviceSearchEngine.search(
    devices: homeDevices,
    query: query,
    typeFilter: typeFilter,
    statusFilter: statusFilter,
    sortBy: sortBy,
  );
});
