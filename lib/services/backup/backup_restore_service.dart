import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/automation_rule.dart';
import '../../core/models/backup_payload.dart';
import '../../core/models/dashboard_config.dart';
import '../../core/models/home.dart';
import '../../core/models/room.dart';
import '../../core/models/smart_device.dart';
import '../../core/models/user_profile.dart';
import '../security/secret_sanitizer.dart';
import '../storage/home_persistence_manager.dart';
import 'backup_validation_service.dart';

/// Current backup schema version.
const int backupSchemaVersion = 6;

/// Maximum payload size allowed for import (5 MB).
const int maxBackupPayloadBytes = 5 * 1024 * 1024;

/// Engine for versioned, transactional, rollback-safe backup export and restore.
class BackupRestoreService {
  const BackupRestoreService();

  /// Supported schema version for export.
  static const int schemaVersion = backupSchemaVersion;

  static bool _isRestoring = false;

  /// Returns true if a restore operation is currently executing.
  static bool get isRestoring => _isRestoring;

  /// Resets the concurrency lock (for testing purposes).
  static void resetConcurrencyLock() {
    _isRestoring = false;
  }

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

    final sanitizedHomes = state.homes
        .map((h) => SecretSanitizer.sanitizeMap(h.toJson()))
        .toList();
    final sanitizedRooms = state.rooms
        .map((r) => SecretSanitizer.sanitizeMap(r.toJson()))
        .toList();
    final sanitizedDevices = state.devices
        .map((d) => SecretSanitizer.sanitizeMap(d.toJson()))
        .toList();
    final sanitizedScenes = state.scenes
        .map((s) => SecretSanitizer.sanitizeMap(s.toJson()))
        .toList();
    final sanitizedAutomations = state.automations
        .map((a) => SecretSanitizer.sanitizeMap(a.toJson()))
        .toList();
    final dashboardConfigs = state.homes
        .map((h) => SecretSanitizer.sanitizeMap(
            (state.dashboardConfigs[h.id] ?? DashboardConfig.defaultFor(h.id))
                .toJson()))
        .toList();
    final sanitizedUserProfile =
        SecretSanitizer.sanitizeMap(state.userProfile.toJson());

    final metadata = BackupMetadata(
      schemaVersion: backupSchemaVersion,
      exportedAt: DateTime.now(),
      lumivoVersion: '1.0.0-rc.1',
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
    final result = BackupValidationService.validate(jsonString);
    return result.previewSummary ??
        BackupPreviewSummary(
          schemaVersion: 0,
          isValid: result.isValid,
          homeCount: 0,
          roomCount: 0,
          deviceCount: 0,
          sceneCount: 0,
          automationCount: 0,
          errors: result.errors,
        );
  }

  /// Validates [jsonString] without applying changes and returns a [BackupPreviewSummary].
  Future<BackupPreviewSummary> validateAndPreviewBackup(
      String jsonString) async {
    return validateSync(jsonString);
  }

  /// Transactional, rollback-safe restore of [jsonString] into [persistenceManager].
  ///
  /// Executes the 9-step atomic restore pipeline:
  /// Concurrency Guard -> Pre-restore Snapshot -> Parse -> Validate -> Normalize ->
  /// Verify references -> Build Candidate -> Apply -> Verify Integrity -> Commit (or Rollback on failure).
  Future<bool> restoreBackup({
    required String jsonString,
    required HomePersistenceManager persistenceManager,
  }) async {
    // Concurrency Lock: Guard restore execution against concurrent state changes
    if (_isRestoring) {
      return false;
    }
    _isRestoring = true;

    // Pre-restore snapshot: take full snapshot before applying
    HomeState? previousState;
    try {
      previousState = persistenceManager.cachedState ??
          await persistenceManager.loadHomeState();
    } catch (_) {
      previousState = persistenceManager.createDemoState();
    }

    try {
      await persistenceManager.saveSnapshotBackup(previousState);

      // Step 1: Parse
      dynamic decoded;
      try {
        decoded = jsonDecode(jsonString);
      } catch (_) {
        return false;
      }
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      // Step 2: Validate using BackupValidationService
      final validationResult = BackupValidationService.validate(jsonString);
      if (!validationResult.isValid) {
        return false;
      }

      // Step 3: Normalize (handle schemas V1 through V6)
      final payload = BackupPayload.fromJson(decoded);

      List<Home> homes = payload.homes.map((h) => Home.fromJson(h)).toList();
      if (homes.isEmpty) {
        homes = List.of(HomePersistenceManager.defaultHomes);
      }

      final rooms = payload.rooms.map((r) {
        final rMap = Map<String, dynamic>.from(r);
        if (rMap['homeId'] == null || (rMap['homeId'] as String).isEmpty) {
          rMap['homeId'] = homes.first.id;
        }
        return Room.fromJson(rMap);
      }).toList();

      final devices = payload.devices.map((d) {
        final dMap = Map<String, dynamic>.from(d);
        if (dMap['homeId'] == null || (dMap['homeId'] as String).isEmpty) {
          dMap['homeId'] = homes.first.id;
        }
        if (dMap['customData'] is Map) {
          dMap['customData'] = SecretSanitizer.sanitizeMap(
              Map<String, dynamic>.from(dMap['customData'] as Map));
        }
        return SmartDevice.fromJson(dMap);
      }).toList();

      final scenes = payload.scenes.map((s) {
        final sMap = Map<String, dynamic>.from(s);
        if (sMap['homeId'] == null || (sMap['homeId'] as String).isEmpty) {
          sMap['homeId'] = homes.first.id;
        }
        return Scene.fromJson(sMap);
      }).toList();

      final automations = payload.automations.map((a) {
        final aMap = Map<String, dynamic>.from(a);
        if (aMap['homeId'] == null || (aMap['homeId'] as String).isEmpty) {
          aMap['homeId'] = homes.first.id;
        }
        return AutomationRule.fromJson(aMap);
      }).toList();

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

      // Step 4: Verify references
      final homeIdSet = homes.map((h) => h.id).toSet();
      final roomIdSet = rooms.map((r) => r.id).toSet();
      final deviceIdSet = devices.map((d) => d.id).toSet();

      for (final dev in devices) {
        if (!homeIdSet.contains(dev.homeId)) {
          throw StateError(
              'Device "${dev.id}" references invalid home: ${dev.homeId}');
        }
        if (roomIdSet.isNotEmpty && !roomIdSet.contains(dev.roomId)) {
          throw StateError(
              'Device "${dev.id}" references invalid room: ${dev.roomId}');
        }
      }

      for (final scene in scenes) {
        for (final act in scene.actions) {
          if (!deviceIdSet.contains(act.deviceId)) {
            throw StateError(
                'Scene "${scene.id}" references invalid device: ${act.deviceId}');
          }
        }
      }

      for (final auto in automations) {
        for (final act in auto.actions) {
          if (!deviceIdSet.contains(act.deviceId)) {
            throw StateError(
                'Automation "${auto.id}" references invalid device: ${act.deviceId}');
          }
        }
        if (auto.sensorDeviceId != null && auto.sensorDeviceId!.isNotEmpty) {
          if (!deviceIdSet.contains(auto.sensorDeviceId)) {
            throw StateError(
                'Automation "${auto.id}" references invalid sensor: ${auto.sensorDeviceId}');
          }
        }
      }

      // Step 5: Build candidate state
      final candidateState = previousState.copyWith(
        schemaVersion: HomePersistenceManager.schemaVersion,
        homes: homes,
        rooms: rooms,
        devices: devices,
        scenes: scenes,
        automations: automations,
        userProfile: userProfile,
        currentHomeId: currentHomeId,
        dashboardConfigs: configs,
      );

      // Step 6: Apply candidate state
      await persistenceManager.saveHomeState(candidateState);

      // Step 7: Verify integrity
      final verified = persistenceManager.cachedState;
      if (verified == null ||
          verified.schemaVersion != HomePersistenceManager.schemaVersion ||
          verified.homes.isEmpty) {
        throw StateError(
            'Integrity verification failed on applied candidate state.');
      }

      // Step 8: Commit
      return true;
    } catch (_) {
      // Step 9: Compensating rollback on failure
      try {
        await persistenceManager.saveHomeState(previousState);
      } catch (_) {}
      return false;
    } finally {
      _isRestoring = false;
    }
  }
}

/// Riverpod provider for [BackupRestoreService].
final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return const BackupRestoreService();
});
