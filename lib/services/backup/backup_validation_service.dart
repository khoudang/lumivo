import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/backup_payload.dart';

/// Service providing strict, zero-crash schema validation, structural integrity,
/// entity bounding, and referential verification for Lumivo backup archives.
class BackupValidationService {
  const BackupValidationService();

  static const int defaultMaxSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxNestingDepth = 10;
  static const int maxDevicesLimit = 500;
  static const int maxRoomsLimit = 100;
  static const int maxScenesLimit = 200;
  static const int maxAutomationsLimit = 200;
  static const int maxEventsLimit = 500;
  static const int maxStringLength = 128;

  /// Validates [rawJson] payload and returns a comprehensive [BackupValidationResult].
  /// Never throws uncaught exceptions.
  static BackupValidationResult validate(
    String rawJson, {
    int maxSizeBytes = defaultMaxSizeBytes,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // 1. Empty payload check
    if (rawJson.trim().isEmpty) {
      errors.add('Payload is empty.');
      return BackupValidationResult(
        isValid: false,
        errors: List.unmodifiable(errors),
        warnings: const [],
        previewSummary: const BackupPreviewSummary(
          schemaVersion: 0,
          isValid: false,
          homeCount: 0,
          roomCount: 0,
          deviceCount: 0,
          sceneCount: 0,
          automationCount: 0,
          errors: ['Payload is empty.'],
        ),
      );
    }

    // 2. File size limit
    if (rawJson.length > maxSizeBytes ||
        utf8.encode(rawJson).length > maxSizeBytes) {
      errors.add(
        'Payload exceeds maximum allowed size (5MB).',
      );
      return BackupValidationResult(
        isValid: false,
        errors: List.unmodifiable(errors),
        warnings: const [],
        previewSummary: BackupPreviewSummary(
          schemaVersion: 0,
          isValid: false,
          homeCount: 0,
          roomCount: 0,
          deviceCount: 0,
          sceneCount: 0,
          automationCount: 0,
          errors: List.unmodifiable(errors),
        ),
      );
    }

    // 3. JSON parsing
    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (e) {
      errors.add('Malformed JSON payload: $e');
      return BackupValidationResult(
        isValid: false,
        errors: List.unmodifiable(errors),
        warnings: const [],
        previewSummary: BackupPreviewSummary(
          schemaVersion: 0,
          isValid: false,
          homeCount: 0,
          roomCount: 0,
          deviceCount: 0,
          sceneCount: 0,
          automationCount: 0,
          errors: List.unmodifiable(errors),
        ),
      );
    }

    // 4. Root JSON object validation
    if (decoded is! Map<String, dynamic>) {
      errors.add('Root payload must be a JSON object.');
      return BackupValidationResult(
        isValid: false,
        errors: List.unmodifiable(errors),
        warnings: const [],
        previewSummary: BackupPreviewSummary(
          schemaVersion: 0,
          isValid: false,
          homeCount: 0,
          roomCount: 0,
          deviceCount: 0,
          sceneCount: 0,
          automationCount: 0,
          errors: List.unmodifiable(errors),
        ),
      );
    }

    // 5. Nesting depth limit check (reject depth > 10)
    final depth = _calculateNestingDepth(decoded);
    if (depth > maxNestingDepth) {
      errors.add(
        'Payload nesting depth exceeds maximum allowed limit of 10 (detected: $depth).',
      );
    }

    // 6. Supported schema version checking (1 to 6)
    int? schemaVersion;
    final metadata = decoded['metadata'];
    if (metadata is Map) {
      final v = metadata['schemaVersion'];
      if (v != null) {
        if (v is int) {
          schemaVersion = v;
        } else {
          errors.add(
              'Field "schemaVersion" must be an integer, got: ${v.runtimeType}.');
        }
      }
      if (metadata['exportedAt'] != null) {
        final expStr = metadata['exportedAt'].toString();
        if (DateTime.tryParse(expStr) == null) {
          errors.add(
              'Invalid ISO-8601 timestamp in metadata.exportedAt: "$expStr"');
        }
      }
    }
    final topVer = decoded['schemaVersion'];
    if (topVer != null) {
      if (topVer is int) {
        schemaVersion ??= topVer;
      } else {
        errors.add(
            'Field "schemaVersion" must be an integer, got: ${topVer.runtimeType}.');
      }
    }

    if (schemaVersion == null) {
      errors.add('Missing schemaVersion in metadata.');
    } else if (schemaVersion <= 0 || schemaVersion > 6) {
      errors.add(
        'Unsupported schema version: $schemaVersion (supported: 1-6).',
      );
    }

    // 7. Extract entity collections
    final homesRaw = decoded['homes'];
    final roomsRaw = decoded['rooms'];
    final devicesRaw = decoded['devices'];
    final scenesRaw = decoded['scenes'];
    final automationsRaw = decoded['automations'];
    final eventsRaw = decoded['activityEvents'] ?? decoded['events'];

    if (homesRaw != null && homesRaw is! List) {
      errors.add('Field "homes" must be a list.');
    }
    if (roomsRaw != null && roomsRaw is! List) {
      errors.add('Field "rooms" must be a list.');
    }
    if (devicesRaw != null && devicesRaw is! List) {
      errors.add('Field "devices" must be a list.');
    }
    if (scenesRaw != null && scenesRaw is! List) {
      errors.add('Field "scenes" must be a list.');
    }
    if (automationsRaw != null && automationsRaw is! List) {
      errors.add('Field "automations" must be a list.');
    }
    if (eventsRaw != null && eventsRaw is! List) {
      errors.add('Field "events" must be a list.');
    }

    final homeList = homesRaw is List ? homesRaw : const [];
    final roomList = roomsRaw is List ? roomsRaw : const [];
    final deviceList = devicesRaw is List ? devicesRaw : const [];
    final sceneList = scenesRaw is List ? scenesRaw : const [];
    final automationList = automationsRaw is List ? automationsRaw : const [];
    final eventList = eventsRaw is List ? eventsRaw : const [];

    // 8. Entity count limits
    if (deviceList.length > maxDevicesLimit) {
      errors.add(
        'Device count exceeds limit of $maxDevicesLimit: ${deviceList.length}',
      );
    }
    if (roomList.length > maxRoomsLimit) {
      errors.add(
        'Room count exceeds limit of $maxRoomsLimit: ${roomList.length}',
      );
    }
    if (sceneList.length > maxScenesLimit) {
      errors.add(
        'Scene count exceeds limit of $maxScenesLimit: ${sceneList.length}',
      );
    }
    if (automationList.length > maxAutomationsLimit) {
      errors.add(
        'Automation count exceeds limit of $maxAutomationsLimit: ${automationList.length}',
      );
    }
    if (eventList.length > maxEventsLimit) {
      errors.add(
        'Event count exceeds limit of $maxEventsLimit: ${eventList.length}',
      );
    }

    // 9. Homes validation & unique IDs
    final homeIds = <String>{};
    for (int i = 0; i < homeList.length; i++) {
      final item = homeList[i];
      if (item is! Map) {
        errors.add('Home at index $i must be a JSON object.');
        continue;
      }
      final id = item['id'];
      if (id == null || id.toString().trim().isEmpty) {
        errors.add('Home at index $i is missing required non-null "id".');
      } else if (id is! String) {
        errors.add('Home ID must be a string, got ${id.runtimeType}.');
      } else {
        _checkStringLength('home.id', id, errors);
        if (!homeIds.add(id)) {
          errors.add('Duplicate home ID found: $id');
        }
      }
      final name = item['name'];
      if (name == null || name.toString().trim().isEmpty) {
        errors.add('Home "${item['id'] ?? i}" is missing required "name".');
      } else {
        _checkStringLength('home.name', name.toString(), errors);
      }
    }

    // 10. Rooms validation & unique IDs
    final roomIds = <String>{};
    final roomHomeMap = <String, String>{};
    for (int i = 0; i < roomList.length; i++) {
      final item = roomList[i];
      if (item is! Map) {
        errors.add('Room at index $i must be a JSON object.');
        continue;
      }
      final id = item['id'];
      if (id == null || id.toString().trim().isEmpty) {
        errors.add('Room at index $i is missing required non-null "id".');
      } else if (id is! String) {
        errors.add('Room ID must be a string, got ${id.runtimeType}.');
      } else {
        _checkStringLength('room.id', id, errors);
        if (!roomIds.add(id)) {
          errors.add('Duplicate room ID found: $id');
        }
      }
      final name = item['name'];
      if (name == null || name.toString().trim().isEmpty) {
        errors.add('Room "${item['id'] ?? i}" is missing required "name".');
      } else {
        _checkStringLength('room.name', name.toString(), errors);
      }
      // Check homeId reference if homes are defined
      if (item['homeId'] != null) {
        final hId = item['homeId'].toString();
        if (id is String) {
          roomHomeMap[id] = hId;
        }
        if (homeIds.isNotEmpty && !homeIds.contains(hId)) {
          errors.add(
              'Room "${item['id'] ?? i}" references non-existent home: $hId');
        }
      }
    }

    // 11. Devices validation, unique IDs, numeric bounds, string lengths
    final deviceIds = <String>{};
    final deviceHomeMap = <String, String>{};
    for (int i = 0; i < deviceList.length; i++) {
      final item = deviceList[i];
      if (item is! Map) {
        errors.add('Device at index $i must be a JSON object.');
        continue;
      }
      final id = item['id'];
      if (id == null || id.toString().trim().isEmpty) {
        errors.add('Device at index $i is missing required non-null "id".');
      } else if (id is! String) {
        errors.add('Device ID must be a string, got ${id.runtimeType}.');
      } else {
        _checkStringLength('device.id', id, errors);
        if (!deviceIds.add(id)) {
          errors.add('Duplicate device ID found: $id');
        }
      }
      final devId = item['id']?.toString() ?? 'index-$i';

      final name = item['name'];
      if (name == null || name.toString().trim().isEmpty) {
        errors.add('Device "$devId" is missing required "name".');
      } else {
        _checkStringLength('device.name', name.toString(), errors);
      }

      // Referential integrity: room reference
      final roomId = item['roomId'];
      if (roomId == null || roomId.toString().trim().isEmpty) {
        errors.add('Device "$devId" is missing required "roomId".');
      } else {
        final rId = roomId.toString();
        _checkStringLength('device.roomId', rId, errors);
        if (roomIds.isNotEmpty && !roomIds.contains(rId)) {
          errors.add('Device "$devId" references non-existent room: $rId');
        }
      }

      // Referential integrity: home reference
      if (item['homeId'] != null) {
        final hId = item['homeId'].toString();
        if (id is String) {
          deviceHomeMap[id] = hId;
        }
        if (homeIds.isNotEmpty && !homeIds.contains(hId)) {
          errors.add('Device "$devId" references non-existent home: $hId');
        }
      }

      // Referential integrity: device home vs room home
      if (item['homeId'] != null && roomId != null) {
        final devHome = item['homeId'].toString();
        final rId = roomId.toString();
        final roomHome = roomHomeMap[rId];
        if (roomHome != null && roomHome != devHome) {
          errors.add(
            'Device "${item['id']}" belongs to home "$devHome" but references room "$rId" belonging to home "$roomHome".',
          );
        }
      }

      // Numeric bounds: powerUsageWatts in [0, 10000]
      if (item['powerUsageWatts'] != null) {
        final watts = item['powerUsageWatts'];
        if (watts is num) {
          if (watts < 0 || watts > 10000) {
            errors.add(
              'Device "$devId" powerUsageWatts ($watts) out of bounds [0, 10000].',
            );
          }
        } else {
          errors.add('Device "$devId" powerUsageWatts must be a number.');
        }
      }

      // Numeric bounds: brightness in [0, 100]
      if (item['brightness'] != null) {
        final brightness = item['brightness'];
        if (brightness is num) {
          if (brightness < 0 || brightness > 100) {
            errors.add(
              'Device "$devId" brightness ($brightness) out of bounds [0, 100].',
            );
          }
        } else {
          errors.add('Device "$devId" brightness must be a number.');
        }
      }

      // Numeric bounds: targetTemperature in [10, 40]
      if (item['targetTemperature'] != null) {
        final temp = item['targetTemperature'];
        if (temp is num) {
          if (temp < 10 || temp > 40) {
            errors.add(
              'Device "$devId" targetTemperature ($temp) out of bounds [10, 40] C.',
            );
          }
        } else {
          errors.add('Device "$devId" targetTemperature must be a number.');
        }
      }

      // Numeric bounds: currentTemperature in [10, 40]
      if (item['currentTemperature'] != null) {
        final temp = item['currentTemperature'];
        if (temp is num) {
          if (temp < 10 || temp > 40) {
            errors.add(
              'Device "$devId" currentTemperature ($temp) out of bounds [10, 40] C.',
            );
          }
        } else {
          errors.add('Device "$devId" currentTemperature must be a number.');
        }
      }
    }

    // 12. Scenes validation, unique IDs & device referential integrity
    final sceneIds = <String>{};
    for (int i = 0; i < sceneList.length; i++) {
      final item = sceneList[i];
      if (item is! Map) {
        errors.add('Scene at index $i must be a JSON object.');
        continue;
      }
      final id = item['id'];
      if (id == null || id.toString().trim().isEmpty) {
        errors.add('Scene at index $i is missing required non-null "id".');
      } else {
        final idStr = id.toString();
        _checkStringLength('scene.id', idStr, errors);
        if (!sceneIds.add(idStr)) {
          errors.add('Duplicate scene ID found: $idStr');
        }
      }
      final sceneId =
          item['id']?.toString() ?? item['name']?.toString() ?? 'index-$i';

      final sceneHome = item['homeId']?.toString();
      final actions = item['actions'];
      if (actions is List) {
        for (final act in actions) {
          if (act is Map && act['deviceId'] != null) {
            final devId = act['deviceId'].toString();
            if (!deviceIds.contains(devId)) {
              errors.add(
                'Scene "$sceneId" references non-existent device: $devId',
              );
            } else if (sceneHome != null &&
                sceneHome.isNotEmpty &&
                deviceHomeMap[devId] != null &&
                deviceHomeMap[devId] != sceneHome) {
              errors.add(
                'Scene "$sceneId" belongs to home "$sceneHome" but action targets device "$devId" belonging to home "${deviceHomeMap[devId]}".',
              );
            }
          }
        }
      }
    }

    // 13. Automations validation, unique IDs & device referential integrity
    final automationIds = <String>{};
    for (int i = 0; i < automationList.length; i++) {
      final item = automationList[i];
      if (item is! Map) {
        errors.add('Automation at index $i must be a JSON object.');
        continue;
      }
      final id = item['id'];
      if (id == null || id.toString().trim().isEmpty) {
        errors.add('Automation at index $i is missing required non-null "id".');
      } else {
        final idStr = id.toString();
        _checkStringLength('automation.id', idStr, errors);
        if (!automationIds.add(idStr)) {
          errors.add('Duplicate automation ID found: $idStr');
        }
      }
      final autoId =
          item['id']?.toString() ?? item['name']?.toString() ?? 'index-$i';

      final autoHome = item['homeId']?.toString();
      final actions = item['actions'];
      if (actions is List) {
        for (final act in actions) {
          if (act is Map && act['deviceId'] != null) {
            final devId = act['deviceId'].toString();
            if (!deviceIds.contains(devId)) {
              errors.add(
                'Automation "$autoId" action references non-existent device: $devId',
              );
            } else if (autoHome != null &&
                autoHome.isNotEmpty &&
                deviceHomeMap[devId] != null &&
                deviceHomeMap[devId] != autoHome) {
              errors.add(
                'Automation "$autoId" belongs to home "$autoHome" but action targets device "$devId" belonging to home "${deviceHomeMap[devId]}".',
              );
            }
          }
        }
      }

      final sensorDevId = item['sensorDeviceId'];
      if (sensorDevId != null && sensorDevId.toString().trim().isNotEmpty) {
        final sId = sensorDevId.toString();
        if (!deviceIds.contains(sId)) {
          errors.add(
            'Automation "$autoId" sensor references non-existent device: $sId',
          );
        } else if (autoHome != null &&
            autoHome.isNotEmpty &&
            deviceHomeMap[sId] != null &&
            deviceHomeMap[sId] != autoHome) {
          errors.add(
            'Automation "$autoId" belongs to home "$autoHome" but sensor references device "$sId" belonging to home "${deviceHomeMap[sId]}".',
          );
        }
      }
    }

    // 14. Events validation, unique IDs & ISO-8601 timestamps
    final eventIds = <String>{};
    for (int i = 0; i < eventList.length; i++) {
      final item = eventList[i];
      if (item is! Map) continue;
      final id = item['id'];
      if (id != null) {
        final idStr = id.toString();
        if (!eventIds.add(idStr)) {
          errors.add('Duplicate event ID found: $idStr');
        }
      }
      if (item['timestamp'] != null) {
        final ts = item['timestamp'].toString();
        if (DateTime.tryParse(ts) == null) {
          errors.add(
              'Invalid ISO-8601 timestamp in event "${item['id'] ?? i}": "$ts"');
        }
      }
    }

    final preview = BackupPreviewSummary(
      schemaVersion: schemaVersion ?? 0,
      isValid: errors.isEmpty,
      homeCount: homeList.length,
      roomCount: roomList.length,
      deviceCount: deviceList.length,
      sceneCount: sceneList.length,
      automationCount: automationList.length,
      errors: List.unmodifiable(errors),
    );

    return BackupValidationResult(
      isValid: errors.isEmpty,
      errors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
      previewSummary: preview,
    );
  }

  /// Instance method proxying static [validate].
  BackupValidationResult validateSync(
    String rawJson, {
    int maxSizeBytes = defaultMaxSizeBytes,
  }) =>
      validate(rawJson, maxSizeBytes: maxSizeBytes);

  /// Recursively computes max nesting depth of decoded JSON.
  static int _calculateNestingDepth(dynamic value) {
    if (value is Map) {
      if (value.isEmpty) return 1;
      int maxChild = 0;
      for (final v in value.values) {
        final d = _calculateNestingDepth(v);
        if (d > maxChild) maxChild = d;
      }
      return 1 + maxChild;
    } else if (value is List) {
      if (value.isEmpty) return 1;
      int maxChild = 0;
      for (final v in value) {
        final d = _calculateNestingDepth(v);
        if (d > maxChild) maxChild = d;
      }
      return 1 + maxChild;
    }
    return 0;
  }

  static void _checkStringLength(
    String fieldName,
    String value,
    List<String> errors, {
    int maxLength = maxStringLength,
  }) {
    if (value.length > maxLength) {
      errors.add(
        'Field "$fieldName" exceeds maximum allowed length of $maxLength characters (${value.length} chars).',
      );
    }
  }
}

/// Riverpod provider for [BackupValidationService].
final backupValidationServiceProvider =
    Provider<BackupValidationService>((ref) {
  return const BackupValidationService();
});
