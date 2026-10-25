import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/backup_payload.dart';
import '../../../services/backup/backup_restore_service.dart';
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
  BackupRestoreNotifier({
    required HomePersistenceManager persistenceManager,
    BackupRestoreService? service,
  })  : _persistenceManager = persistenceManager,
        _service = service ?? const BackupRestoreService(),
        super(const BackupRestoreState());

  final HomePersistenceManager _persistenceManager;
  final BackupRestoreService _service;

  Future<String> exportBackup() async {
    try {
      final jsonString = await _service.exportBackupJson(
        persistenceManager: _persistenceManager,
      );
      state = state.copyWith(
        lastExportJson: jsonString,
        clearError: true,
        successMessage: 'Backup exported successfully',
      );
      return jsonString;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Export failed: $e',
      );
      rethrow;
    }
  }

  BackupPreviewSummary previewBackup(String jsonString) {
    final summary = _service.validateSync(jsonString);
    state = state.copyWith(previewSummary: summary);
    return summary;
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
      final success = await _service.restoreBackup(
        jsonString: jsonString,
        persistenceManager: _persistenceManager,
      );

      if (success) {
        state = state.copyWith(
          isRestoring: false,
          clearError: true,
          successMessage: 'Backup successfully restored',
        );
        return true;
      } else {
        state = state.copyWith(
          isRestoring: false,
          errorMessage: 'Restore failed: Error applying backup payload',
        );
        return false;
      }
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
