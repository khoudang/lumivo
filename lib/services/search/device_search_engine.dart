import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/smart_device.dart';

/// In-memory search and filtering engine for [SmartDevice]s with strict home scoping.
class DeviceSearchEngine {
  const DeviceSearchEngine();

  /// Searches and filters [allDevices] based on query, type, online status,
  /// strictly scoped to [homeId], and sorted according to [sortBy].
  ///
  /// Supported sort options:
  /// - `'name'`: alphabetical order (A-Z).
  /// - `'room'`: grouped by room name, then device name.
  /// - `'recent'`: active devices first (isOn), then descending wattage, then device name.
  List<SmartDevice> search({
    required List<SmartDevice> allDevices,
    required String homeId,
    String? query,
    DeviceType? type,
    bool? isOnline,
    String sortBy = 'name',
  }) {
    // 1. Strict home scoping: never return devices from other homes
    final scoped = allDevices.where((d) => d.homeId == homeId);

    // 2. Filter by type if provided
    final typeFiltered =
        type != null ? scoped.where((d) => d.type == type) : scoped;

    // 3. Filter by online status if provided
    final statusFiltered = isOnline != null
        ? typeFiltered
            .where((d) => (d.connection == DeviceConnection.online) == isOnline)
        : typeFiltered;

    // 4. Filter by query (case-insensitive substring match on device name or roomId)
    final results = query != null && query.trim().isNotEmpty
        ? statusFiltered.where((d) {
            final q = query.trim().toLowerCase();
            return d.name.toLowerCase().contains(q) ||
                d.roomId.toLowerCase().contains(q);
          }).toList()
        : statusFiltered.toList();

    // 5. Deterministic sorting
    final normalizedSort = sortBy.trim().toLowerCase();
    switch (normalizedSort) {
      case 'room':
        results.sort((a, b) {
          final roomComp =
              a.roomId.toLowerCase().compareTo(b.roomId.toLowerCase());
          if (roomComp != 0) return roomComp;
          final nameComp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (nameComp != 0) return nameComp;
          return a.id.compareTo(b.id);
        });
        break;

      case 'recent':
        // Active devices first, then higher power wattage, then alphabetical name
        results.sort((a, b) {
          if (a.isOn != b.isOn) {
            return b.isOn ? 1 : -1;
          }
          final powerComp = b.powerUsageWatts.compareTo(a.powerUsageWatts);
          if (powerComp != 0) return powerComp;
          final nameComp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (nameComp != 0) return nameComp;
          return a.id.compareTo(b.id);
        });
        break;

      case 'name':
      default:
        results.sort((a, b) {
          final nameComp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (nameComp != 0) return nameComp;
          return a.id.compareTo(b.id);
        });
        break;
    }

    return results;
  }
}

/// Riverpod provider for [DeviceSearchEngine].
final deviceSearchEngineProvider = Provider<DeviceSearchEngine>((ref) {
  return const DeviceSearchEngine();
});
