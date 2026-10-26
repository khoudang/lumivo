class BackupMetadata {
  const BackupMetadata({
    required this.schemaVersion,
    required this.exportedAt,
    required this.lumivoVersion,
    required this.homeCount,
    required this.deviceCount,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final String lumivoVersion;
  final int homeCount;
  final int deviceCount;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'lumivoVersion': lumivoVersion,
        'homeCount': homeCount,
        'deviceCount': deviceCount,
      };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
        schemaVersion: json['schemaVersion'] as int? ?? 6,
        exportedAt: json['exportedAt'] != null
            ? DateTime.tryParse(json['exportedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        lumivoVersion: json['lumivoVersion'] as String? ?? '0.6.0',
        homeCount: json['homeCount'] as int? ?? 1,
        deviceCount: json['deviceCount'] as int? ?? 0,
      );
}

class BackupPreviewSummary {
  const BackupPreviewSummary({
    required this.schemaVersion,
    required this.isValid,
    required this.homeCount,
    required this.roomCount,
    required this.deviceCount,
    required this.sceneCount,
    required this.automationCount,
    this.errors = const [],
  });

  final int schemaVersion;
  final bool isValid;
  final int homeCount;
  final int roomCount;
  final int deviceCount;
  final int sceneCount;
  final int automationCount;
  final List<String> errors;
}

class BackupPayload {
  const BackupPayload({
    required this.metadata,
    required this.homes,
    required this.rooms,
    required this.devices,
    required this.scenes,
    required this.automations,
    this.dashboardConfigs = const [],
    this.userProfile,
  });

  final BackupMetadata metadata;
  final List<Map<String, dynamic>> homes;
  final List<Map<String, dynamic>> rooms;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> scenes;
  final List<Map<String, dynamic>> automations;
  final List<Map<String, dynamic>> dashboardConfigs;
  final Map<String, dynamic>? userProfile;

  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'homes': homes,
        'rooms': rooms,
        'devices': devices,
        'scenes': scenes,
        'automations': automations,
        'dashboardConfigs': dashboardConfigs,
        'userProfile': userProfile,
      };

  factory BackupPayload.fromJson(Map<String, dynamic> json) => BackupPayload(
        metadata: BackupMetadata.fromJson(
            json['metadata'] as Map<String, dynamic>? ?? {}),
        homes: (json['homes'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        rooms: (json['rooms'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        devices: (json['devices'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        scenes: (json['scenes'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        automations: (json['automations'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        dashboardConfigs: (json['dashboardConfigs'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        userProfile: json['userProfile'] != null
            ? Map<String, dynamic>.from(json['userProfile'] as Map)
            : null,
      );
}

class BackupValidationResult {
  const BackupValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.previewSummary,
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final BackupPreviewSummary? previewSummary;
}
