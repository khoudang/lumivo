import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/backup_payload.dart';
import '../../core/models/dashboard_config.dart';
import '../../core/models/home.dart';
import '../../core/models/room.dart';
import '../../core/models/smart_device.dart';
import '../../core/models/user_profile.dart';
import '../storage/home_persistence_manager.dart';

/// Current backup schema version.
const int backupSchemaVersion = 6;

/// Maximum payload size allowed for import (5 MB).
const int maxBackupPayloadBytes = 5 * 1024 * 1024;

/// Engine for versioned, transactional, rollback-safe backup export and restore.
class BackupRestoreService {
  const BackupRestoreService();

  /// Supported schema version for export.
  static const int schemaVersion = backupSchemaVersion;

  /// Exports full configuration as a sanitized versioned JSON string.
  ///
  /// Backs up: Homes, Rooms, Devices, Favorites, DashboardConfigs,
  /// Scenes, Automations, UserProfile.
  /// Strictly omits passwords, secrets, tokens, and credentials.
  Future<String> exportBackupJson({
    required HomePersistenceManager persistenceManager,
  }) async {
    final state = persistenceManager.cachedState ??
        await persistenceManager.loadHomeState();

    final sanitizedHomes =
        state.homes.map((h) => _sanitizeMap(h.toJson())).toList();
    final sanitizedRooms =
        state.rooms.map((r) => _sanitizeMap(r.toJson())).toList();
    final sanitizedDevices =
        state.devices.map((d) => _sanitizeMap(d.toJson())).toList();
    final sanitizedScenes =
        state.scenes.map((s) => _sanitizeMap(s.toJson())).toList();
    final sanitizedAutomations =
        state.automations.map((a) => _sanitizeMap(a.toJson())).toList();
    final dashboardConfigs = state.homes
        .map((h) => _sanitizeMap(
            (state.dashboardConfigs[h.id] ?? DashboardConfig.defaultFor(h.id))
                .toJson()))
        .toList();
    final sanitizedUserProfile = _sanitizeMap(state.userProfile.toJson());

    final metadata = BackupMetadata(
      schemaVersion: backupSchemaVersion,
      exportedAt: DateTime.now(),
      lumivoVersion: '0.6.0',
      homeCount: sanitizedHomes.length,
      deviceCount: sanitizedDevices.length,
    );

    final payload = BackupPayload(
      metadata: metadata,
      homes: sanitizedHomes,
      rooms: sanitizedRooms,
      devices: sanitizedDevices,
      scenes: sanitizedScenes,
      automations: sanitizedAutomations,
      dashboardConfigs: dashboardConfigs,
      userProfile: sanitizedUserProfile,
    );

    return const JsonEncoder.withIndent('  ').convert(payload.toJson());
  }

  /// Synchronously validates [jsonString] without applying changes and returns a [BackupPreviewSummary].
  BackupPreviewSummary validateSync(String jsonString) {
    final errors = <String>[];

    if (jsonString.trim().isEmpty) {
      return const BackupPreviewSummary(
        schemaVersion: 0,
        isValid: false,
        homeCount: 0,
        roomCount: 0,
        deviceCount: 0,
        sceneCount: 0,
        automationCount: 0,
        errors: ['Payload is empty.'],
      );
    }

    if (jsonString.length > maxBackupPayloadBytes) {
      return const BackupPreviewSummary(
        schemaVersion: 0,
        isValid: false,
        homeCount: 0,
        roomCount: 0,
        deviceCount: 0,
        sceneCount: 0,
        automationCount: 0,
        errors: ['Payload exceeds maximum allowed size (5MB).'],
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      return BackupPreviewSummary(
        schemaVersion: 0,
        isValid: false,
        homeCount: 0,
        roomCount: 0,
        deviceCount: 0,
        sceneCount: 0,
        automationCount: 0,
        errors: ['Malformed JSON payload: $e'],
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const BackupPreviewSummary(
        schemaVersion: 0,
        isValid: false,
        homeCount: 0,
        roomCount: 0,
        deviceCount: 0,
        sceneCount: 0,
        automationCount: 0,
        errors: ['Root payload must be a JSON object.'],
      );
    }

    // Schema version check
    int? schemaVersion;
    final metadata = decoded['metadata'];
    if (metadata is Map) {
      final v = metadata['schemaVersion'];
      if (v is int) schemaVersion = v;
    }
    schemaVersion ??= decoded['schemaVersion'] as int?;

    if (schemaVersion == null) {
      errors.add('Missing schemaVersion in metadata.');
    } else if (schemaVersion <= 0 || schemaVersion > backupSchemaVersion) {
      errors.add(
        'Unsupported schema version: $schemaVersion (supported: 1-$backupSchemaVersion).',
      );
    }

    // Validate lists and duplicate IDs
    final homesRaw = decoded['homes'];
    final roomsRaw = decoded['rooms'];
    final devicesRaw = decoded['devices'];
    final scenesRaw = decoded['scenes'];
    final automationsRaw = decoded['automations'];

    final homeList = homesRaw is List ? homesRaw : const [];
    final roomList = roomsRaw is List ? roomsRaw : const [];
    final deviceList = devicesRaw is List ? devicesRaw : const [];
    final sceneList = scenesRaw is List ? scenesRaw : const [];
    final automationList = automationsRaw is List ? automationsRaw : const [];

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

    // Check duplicate home IDs
    final homeIds = <String>{};
    for (final item in homeList) {
      if (item is Map && item['id'] != null) {
        final id = item['id'].toString();
        if (!homeIds.add(id)) {
          errors.add('Duplicate home ID found: $id');
        }
      }
    }

    // Check duplicate room IDs
    final roomIds = <String>{};
    for (final item in roomList) {
      if (item is Map && item['id'] != null) {
        final id = item['id'].toString();
        if (!roomIds.add(id)) {
          errors.add('Duplicate room ID found: $id');
        }
      }
    }

    // Check duplicate device IDs
    final deviceIds = <String>{};
    for (final item in deviceList) {
      if (item is Map && item['id'] != null) {
        final id = item['id'].toString();
        if (!deviceIds.add(id)) {
          errors.add('Duplicate device ID found: $id');
        }
      }
    }

    // Check duplicate scene IDs and validate that actions reference valid device IDs
    final sceneIds = <String>{};
    for (final item in sceneList) {
      if (item is Map) {
        if (item['id'] != null) {
          final id = item['id'].toString();
          if (!sceneIds.add(id)) {
            errors.add('Duplicate scene ID found: $id');
          }
        }
        final actions = item['actions'];
        if (actions is List) {
          for (final act in actions) {
            if (act is Map && act['deviceId'] != null) {
              final devId = act['deviceId'].toString();
              if (!deviceIds.contains(devId)) {
                errors.add(
                  'Scene "${item['id'] ?? item['name']}" references non-existent device: $devId',
                );
              }
            }
          }
        }
      }
    }

    // Check duplicate automation IDs and validate device action / sensor references
    final automationIds = <String>{};
    for (final item in automationList) {
      if (item is Map) {
        if (item['id'] != null) {
          final id = item['id'].toString();
          if (!automationIds.add(id)) {
            errors.add('Duplicate automation ID found: $id');
          }
        }
        final actions = item['actions'];
        if (actions is List) {
          for (final act in actions) {
            if (act is Map && act['deviceId'] != null) {
              final devId = act['deviceId'].toString();
              if (!deviceIds.contains(devId)) {
                errors.add(
                  'Automation "${item['id'] ?? item['name']}" action references non-existent device: $devId',
                );
              }
            }
          }
        }
        final sensorDevId = item['sensorDeviceId'];
        if (sensorDevId != null && sensorDevId.toString().isNotEmpty) {
          final sId = sensorDevId.toString();
          if (!deviceIds.contains(sId)) {
            errors.add(
              'Automation "${item['id'] ?? item['name']}" sensor references non-existent device: $sId',
            );
          }
        }
      }
    }

    return BackupPreviewSummary(
      schemaVersion: schemaVersion ?? 0,
      isValid: errors.isEmpty,
      homeCount: homeList.length,
      roomCount: roomList.length,
      deviceCount: deviceList.length,
      sceneCount: sceneList.length,
      automationCount: automationList.length,
      errors: List.unmodifiable(errors),
    );
  }

  /// Validates [jsonString] without applying changes and returns a [BackupPreviewSummary].
  Future<BackupPreviewSummary> validateAndPreviewBackup(
      String jsonString) async {
    return validateSync(jsonString);
  }

  /// Transactional, rollback-safe restore of [jsonString] into [persistenceManager].
  ///
  /// If validation fails, or if parsing/saving encounters an error, the previous
  /// memory and storage state is preserved without partial updates.
  Future<bool> restoreBackup({
    required String jsonString,
    required HomePersistenceManager persistenceManager,
  }) async {
    // 1. Pre-validation
    final preview = validateSync(jsonString);
    if (!preview.isValid) {
      return false;
    }

    // 2. Snapshot current state for rollback safety
    final previousState = persistenceManager.cachedState ??
        await persistenceManager.loadHomeState();

    try {
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      final payload = BackupPayload.fromJson(parsed);

      final homes = payload.homes.map((h) => Home.fromJson(h)).toList();
      final rooms = payload.rooms.map((r) => Room.fromJson(r)).toList();
      final devices =
          payload.devices.map((d) => SmartDevice.fromJson(d)).toList();
      final scenes = payload.scenes.map((s) => Scene.fromJson(s)).toList();
      final automations =
          payload.automations.map((a) => AutomationRule.fromJson(a)).toList();
      final userProfile = payload.userProfile != null
          ? UserProfile.fromJson(payload.userProfile!)
          : previousState.userProfile;

      final currentHomeId =
          homes.isNotEmpty ? homes.first.id : previousState.currentHomeId;

      final configs = <String, DashboardConfig>{};
      for (final cfgMap in payload.dashboardConfigs) {
        final cfg = DashboardConfig.fromJson(cfgMap);
        configs[cfg.homeId] = cfg;
      }
      for (final home in homes) {
        configs.putIfAbsent(home.id, () => DashboardConfig.defaultFor(home.id));
      }

      final restoredState = previousState.copyWith(
        homes: homes,
        rooms: rooms,
        devices: devices,
        scenes: scenes,
        automations: automations,
        userProfile: userProfile,
        currentHomeId: currentHomeId,
        dashboardConfigs: configs,
      );

      await persistenceManager.saveHomeState(restoredState);
      return true;
    } catch (_) {
      // 3. Rollback on failure
      try {
        await persistenceManager.saveHomeState(previousState);
      } catch (_) {}
      return false;
    }
  }

  /// Recursively cleans sensitive credentials and keys from serialized maps.
  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final keyLower = entry.key.toLowerCase();
      if (_isSensitiveKey(keyLower)) {
        continue;
      }
      final value = entry.value;
      if (value is Map) {
        result[entry.key] = _sanitizeMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[entry.key] = value.map((item) {
          if (item is Map) {
            return _sanitizeMap(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  static bool _isSensitiveKey(String key) {
    return key.contains('password') ||
        key.contains('secret') ||
        key.contains('token') ||
        key.contains('passphrase') ||
        key.contains('credential') ||
        key.contains('private_key') ||
        key.contains('privatekey') ||
        key.contains('api_key') ||
        key.contains('apikey') ||
        key.contains('wifi_pass') ||
        key.contains('auth');
  }
}

/// Riverpod provider for [BackupRestoreService].
final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return const BackupRestoreService();
});
