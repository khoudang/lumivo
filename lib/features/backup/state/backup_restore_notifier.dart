import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/automation_rule.dart';
import '../../../core/models/backup_payload.dart';
import '../../../core/models/dashboard_config.dart';
import '../../../core/models/home.dart';
import '../../../core/models/room.dart';
import '../../../core/models/smart_device.dart';
import '../../../core/models/user_profile.dart';
import '../../../services/storage/home_persistence_manager.dart';

class BackupRestoreState {
  const BackupRestoreState({
    this.lastExportJson,
    this.previewSummary,
    this.isRestoring = false,
    this.errorMessage,
    this.successMessage,
  });

  final String? lastExportJson;
  final BackupPreviewSummary? previewSummary;
  final bool isRestoring;
  final String? errorMessage;
  final String? successMessage;

  BackupRestoreState copyWith({
    String? lastExportJson,
    BackupPreviewSummary? previewSummary,
    bool? isRestoring,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
  }) =>
      BackupRestoreState(
        lastExportJson: lastExportJson ?? this.lastExportJson,
        previewSummary: previewSummary ?? this.previewSummary,
        isRestoring: isRestoring ?? this.isRestoring,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        successMessage: successMessage ?? this.successMessage,
      );
}

class BackupRestoreNotifier extends StateNotifier<BackupRestoreState> {
  BackupRestoreNotifier({required HomePersistenceManager persistenceManager})
      : _persistenceManager = persistenceManager,
        super(const BackupRestoreState());

  final HomePersistenceManager _persistenceManager;

  Future<String> exportBackup() async {
    final state = await _persistenceManager.loadHomeState();

    final metadata = BackupMetadata(
      schemaVersion: HomePersistenceManager.schemaVersion,
      exportedAt: DateTime.now(),
      lumivoVersion: '0.6.0',
      homeCount: state.homes.length,
      deviceCount: state.devices.length,
    );

    final payload = BackupPayload(
      metadata: metadata,
      homes: state.homes.map((h) => h.toJson()).toList(),
      rooms: state.rooms.map((r) => r.toJson()).toList(),
      devices: state.devices.map((d) => d.toJson()).toList(),
      scenes: state.scenes.map((s) => s.toJson()).toList(),
      automations: state.automations.map((a) => a.toJson()).toList(),
      dashboardConfigs:
          state.dashboardConfigs.values.map((c) => c.toJson()).toList(),
      userProfile: state.userProfile.toJson(),
    );

    final jsonString =
        const JsonEncoder.withIndent('  ').convert(payload.toJson());
    state_ = state.copyWith();
    this.state = this.state.copyWith(
          lastExportJson: jsonString,
          clearError: true,
          successMessage: 'Backup exported successfully',
        );
    return jsonString;
  }

  // Temporary variable to prevent unused warning if any
  set state_(HomeState s) {}

  BackupPreviewSummary previewBackup(String jsonString) {
    if (jsonString.trim().isEmpty) {
      final summary = const BackupPreviewSummary(
        schemaVersion: 0,
        isValid: false,
        homeCount: 0,
        roomCount: 0,
        deviceCount: 0,
        sceneCount: 0,
        automationCount: 0,
        errors: ['Backup payload is empty'],
      );
      state = state.copyWith(previewSummary: summary);
      return summary;
    }

    try {
      final parsed = jsonDecode(jsonString);
      if (parsed is! Map<String, dynamic>) {
        final summary = const BackupPreviewSummary(
          schemaVersion: 0,
          isValid: false,
          homeCount: 0,
          roomCount: 0,
          deviceCount: 0,
          sceneCount: 0,
          automationCount: 0,
          errors: ['Backup JSON must be an object'],
        );
        state = state.copyWith(previewSummary: summary);
        return summary;
      }

      final errors = <String>[];
      final metaMap = parsed['metadata'] as Map<String, dynamic>?;
      if (metaMap == null) {
        errors.add('Missing metadata section');
      }

      final version = metaMap?['schemaVersion'] as int? ??
          parsed['schemaVersion'] as int? ??
          0;

      if (version <= 0 || version > HomePersistenceManager.schemaVersion) {
        errors.add(
            'Unsupported schema version: $version (expected <= ${HomePersistenceManager.schemaVersion})');
      }

      if (parsed['homes'] == null || parsed['homes'] is! List) {
        errors.add('Missing or invalid homes array');
      }
      if (parsed['devices'] == null || parsed['devices'] is! List) {
        errors.add('Missing or invalid devices array');
      }

      final homesList = parsed['homes'] as List<dynamic>? ?? [];
      final roomsList = parsed['rooms'] as List<dynamic>? ?? [];
      final devicesList = parsed['devices'] as List<dynamic>? ?? [];
      final scenesList = parsed['scenes'] as List<dynamic>? ?? [];
      final automationsList = parsed['automations'] as List<dynamic>? ?? [];

      final summary = BackupPreviewSummary(
        schemaVersion: version,
        isValid: errors.isEmpty,
        homeCount: homesList.length,
        roomCount: roomsList.length,
        deviceCount: devicesList.length,
        sceneCount: scenesList.length,
        automationCount: automationsList.length,
        errors: errors,
      );

      state = state.copyWith(previewSummary: summary);
      return summary;
    } catch (e) {
      final summary = BackupPreviewSummary(
        schemaVersion: 0,
        isValid: false,
        homeCount: 0,
        roomCount: 0,
        deviceCount: 0,
        sceneCount: 0,
        automationCount: 0,
        errors: ['JSON parse error: $e'],
      );
      state = state.copyWith(previewSummary: summary);
      return summary;
    }
  }

  Future<bool> restoreBackup(String jsonString) async {
    state = state.copyWith(isRestoring: true, clearError: true);
    final summary = previewBackup(jsonString);

    if (!summary.isValid) {
      state = state.copyWith(
        isRestoring: false,
        errorMessage: 'Invalid backup: ${summary.errors.join(', ')}',
      );
      return false;
    }

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

      final configs = <String, DashboardConfig>{};
      for (final cfgMap in payload.dashboardConfigs) {
        final cfg = DashboardConfig.fromJson(cfgMap);
        configs[cfg.homeId] = cfg;
      }
      for (final home in homes) {
        configs.putIfAbsent(home.id, () => DashboardConfig.defaultFor(home.id));
      }

      final userProfile = payload.userProfile != null
          ? UserProfile.fromJson(payload.userProfile!)
          : HomePersistenceManager.defaultUserProfile;

      final currentHomeId = homes.isNotEmpty ? homes.first.id : 'home-default';

      final restoredState = HomeState(
        schemaVersion: HomePersistenceManager.schemaVersion,
        homes: homes,
        currentHomeId: currentHomeId,
        userProfile: userProfile,
        energySamples: HomePersistenceManager.createDefaultEnergySamples(),
        rooms: rooms,
        devices: devices,
        automations: automations,
        scenes: scenes,
        dashboardConfigs: configs,
      );

      await _persistenceManager.saveHomeState(restoredState);

      state = state.copyWith(
        isRestoring: false,
        clearError: true,
        successMessage: 'Backup successfully restored',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        errorMessage: 'Restore failed: $e',
      );
      return false;
    }
  }
}

final backupRestoreProvider =
    StateNotifierProvider<BackupRestoreNotifier, BackupRestoreState>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  return BackupRestoreNotifier(persistenceManager: persistence);
});
