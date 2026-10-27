import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/smart_device.dart';
import 'strings_en.dart';
import 'strings_vi.dart';

/// Production-grade typed localization engine for Lumivo Smart Home.
/// Supports English ('en') and Vietnamese ('vi') with automatic fallback.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('vi'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static AppLocalizations fromLocale(Locale locale) => AppLocalizations(locale);

  static AppLocalizations fromLanguageCode(String code) =>
      AppLocalizations(Locale(code));

  /// Translates a key according to the active locale, falling back to English.
  String translate(String key) {
    if (locale.languageCode == 'vi') {
      final viStr = stringsVi[key];
      if (viStr != null && viStr.isNotEmpty) return viStr;
    }
    return stringsEn[key] ?? key;
  }

  // Navigation
  String get home => translate('nav_home');
  String get rooms => translate('nav_rooms');
  String get automation => translate('nav_automation');
  String get activity => translate('nav_activity');
  String get settings => translate('nav_settings');

  // Greetings & Dashboard
  String get welcomeHome => translate('welcome_home');
  String get smartHomeLookingGood => translate('smart_home_looking_good');
  String get devices => translate('devices');
  String get favorites => translate('favorites');
  String get quickScenes => translate('quick_scenes');
  String get seeAll => translate('see_all');
  String get dragToReorder => translate('drag_to_reorder');
  String get demoModeFootnote => translate('demo_mode_footnote');
  String get noFavoritesPinned => translate('no_favorites_pinned');

  String devicesCount(int count) {
    if (locale.languageCode == 'vi') {
      return '$count thiết bị';
    }
    if (count == 1) {
      return '1 device';
    }
    return '$count devices';
  }

  // Device types
  String get light => translate('device_type_light');
  String get fan => translate('device_type_fan');
  String get climateAc => translate('device_type_ac');
  String get socket => translate('device_type_socket');
  String get curtain => translate('device_type_curtain');
  String get smartLock => translate('device_type_lock');
  String get sensor => translate('device_type_sensor');
  String get security => translate('device_type_security');

  String deviceTypeName(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return light;
      case DeviceType.fan:
        return fan;
      case DeviceType.ac:
        return climateAc;
      case DeviceType.socket:
        return socket;
      case DeviceType.curtain:
        return curtain;
      case DeviceType.lock:
        return smartLock;
      case DeviceType.sensor:
        return sensor;
      case DeviceType.security:
        return security;
    }
  }

  // Metrics & Energy
  String get temperature => translate('temperature');
  String get humidity => translate('humidity');
  String get energyToday => translate('energy_today');
  String get totalKwh => translate('total_kwh');
  String get estimatedCost => translate('estimated_cost');
  String get simulatedTelemetry => translate('simulated_telemetry');
  String get simulatedTelemetryBanner =>
      translate('simulated_telemetry_banner');
  String get energyAnalytics => translate('energy_analytics');
  String get currentTariff => translate('current_tariff');
  String get averageWatts => translate('average_watts');
  String get peakWatts => translate('peak_watts');

  // Common actions
  String get back => translate('back');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get done => translate('done');
  String get add => translate('add');
  String get turnOn => translate('turn_on');
  String get turnOff => translate('turn_off');
  String get active => translate('active');
  String get off => translate('off');
  String get offline => translate('offline');
  String get all => translate('all');
  String get clearHistory => translate('clear_history');

  // Settings & Preferences
  String get preferences => translate('preferences');
  String get electricityTariff => translate('electricity_tariff');
  String get aestheticsTheme => translate('aesthetics_theme');
  String get language => translate('language');
  String get oledPureBlack => translate('oled_pure_black');
  String get oledPureBlackTitle => translate('oled_pure_black_title');
  String get reducedMotion => translate('reduced_motion');
  String get reducedMotionDesc => translate('reduced_motion_desc');
  String get temperatureUnit => translate('temperature_unit');
  String get resetDemoData => translate('reset_demo_data');
  String get resetAll => translate('reset_all');
  String get userProfilePreferences => translate('user_profile_preferences');
  String get themeMode => translate('theme_mode');
  String get aboutLumivo => translate('about_lumivo');
  String get simulationDisclosure => translate('simulation_disclosure');

  // Rooms & Automations
  String get addNewRoom => translate('add_new_room');
  String get roomName => translate('room_name');
  String get automations => translate('automations');
  String get scenes => translate('scenes');
  String get noAutomations => translate('no_automations');
  String get activityTimeline => translate('activity_timeline');
  String get noActivity => translate('no_activity');

  // Onboarding
  String get addDevice => translate('add_device');
  String get discoveredDevices => translate('discovered_devices');
  String get wifiSetup => translate('wifi_setup');
  String get pairingDevice => translate('pairing_device');
  String get deviceReady => translate('device_ready');

  // Phase 5 Getters
  String get healthDashboard => translate('health_dashboard');
  String get systemHealthScore => translate('system_health_score');
  String get healthOptimal => translate('health_optimal');
  String get healthDegraded => translate('health_degraded');
  String get healthOfflineWarning => translate('health_offline_warning');
  String get devicesOnline => translate('devices_online');
  String get devicesOffline => translate('devices_offline');
  String get signalStrength => translate('signal_strength');
  String get activeWarnings => translate('active_warnings');
  String get noWarnings => translate('no_warnings');
  String get simulatedBleScan => translate('simulated_ble_scan');
  String get wifiSetupSimulated => translate('wifi_setup_simulated');
  String get assignRoom => translate('assign_room');
  String get retryPairing => translate('retry_pairing');
  String get pairingTimeout => translate('pairing_timeout');
  String get duplicate => translate('duplicate');
  String get automationDuplicated => translate('automation_duplicated');
  String get executionHistory => translate('execution_history');
  String get viewHistory => translate('view_history');
  String get noHistory => translate('no_history');
  String get ruleValidationError => translate('rule_validation_error');
  String get loopPreventedExplanation =>
      translate('loop_prevented_explanation');
  String get skippedExplanation => translate('skipped_explanation');
  String get demoLab => translate('demo_lab');
  String get forceDeviceOffline => translate('force_device_offline');
  String get reconnectDevice => translate('reconnect_device');
  String get injectPacketLoss => translate('inject_packet_loss');
  String get triggerReconnectStorm => translate('trigger_reconnect_storm');

  // Phase 6 Getters
  String get editDashboard => translate('edit_dashboard');
  String get doneEditing => translate('done_editing');
  String get resetLayout => translate('reset_layout');
  String get saveLayout => translate('save_layout');
  String get sectionReordered => translate('section_reordered');
  String get dashboardCustomized => translate('dashboard_customized');
  String get searchDevices => translate('search_devices');
  String get allTypes => translate('all_types');
  String get allStatuses => translate('all_statuses');
  String get sortName => translate('sort_name');
  String get sortRoom => translate('sort_room');
  String get sortRecent => translate('sort_recent');
  String get noDevicesFound => translate('no_devices_found');
  String get clearFilters => translate('clear_filters');
  String get automationBuilder => translate('automation_builder');
  String get whenTrigger => translate('when_trigger');
  String get ifCondition => translate('if_condition');
  String get thenAction => translate('then_action');
  String get previewScene => translate('preview_scene');
  String get affectedDevices => translate('affected_devices');
  String get templateMorning => translate('template_morning');
  String get templateMovie => translate('template_movie');
  String get templateAway => translate('template_away');
  String get templateNight => translate('template_night');
  String get automationSummary => translate('automation_summary');
  String get perDeviceConsumption => translate('per_device_consumption');
  String get perRoomConsumption => translate('per_room_consumption');
  String get exportCsv => translate('export_csv');
  String get csvExported => translate('csv_exported');
  String get simulatedEnergyNotice => translate('simulated_energy_notice');
  String get backupAndRestore => translate('backup_and_restore');
  String get exportBackup => translate('export_backup');
  String get importBackup => translate('import_backup');
  String get backupPreview => translate('backup_preview');
  String get restoreSuccess => translate('restore_success');
  String get invalidBackupError => translate('invalid_backup_error');
  String get replaceDataWarning => translate('replace_data_warning');

  // Phase 7 — Accessibility, UI Audit & Consumer Experience
  String get brandTagline => translate('brand_tagline');
  String get enterDemoMode => translate('enter_demo_mode');
  String get skipToDashboard => translate('skip_to_dashboard');
  String get featureIotSimTitle => translate('feature_iot_sim_title');
  String get featureIotSimSubtitle => translate('feature_iot_sim_subtitle');
  String get featureIotSimTag => translate('feature_iot_sim_tag');
  String get featureAmbianceTitle => translate('feature_ambiance_title');
  String get featureAmbianceSubtitle => translate('feature_ambiance_subtitle');
  String get featureAmbianceTag => translate('feature_ambiance_tag');
  String get featureEnergyTitle => translate('feature_energy_title');
  String get featureEnergySubtitle => translate('feature_energy_subtitle');
  String get featureEnergyTag => translate('feature_energy_tag');
  String get demoModeCallout => translate('demo_mode_callout');
  String get notifications => translate('notifications');
  String get noNotifications => translate('no_notifications');
  String get markAllRead => translate('mark_all_read');
  String get clearAll => translate('clear_all');
  String get filterAll => translate('filter_all');
  String get filterAutomations => translate('filter_automations');
  String get filterManual => translate('filter_manual');
  String get filterAlerts => translate('filter_alerts');
  String get spacesAndZones => translate('spaces_and_zones');
  String get selectRoomIcon => translate('select_room_icon');
  String get deleteRoom => translate('delete_room');
  String get switchHome => translate('switch_home');
  String get manageActiveProperty => translate('manage_active_property');
  String get availableHomes => translate('available_homes');
  String get addNewHome => translate('add_new_home');
  String get homeName => translate('home_name');
  String get address => translate('address');
  String get tariffRateLabel => translate('tariff_rate_label');
  String get role => translate('role');
  String get owner => translate('owner');
  String get member => translate('member');
  String get editHome => translate('edit_home');
  String get deleteHome => translate('delete_home');

  String deleteHomeConfirm(String name) {
    return translate('delete_home_confirm').replaceAll('{name}', name);
  }

  String get confirmDeleteDeviceTitle =>
      translate('confirm_delete_device_title');
  String confirmDeleteDeviceBody(String name) {
    return translate('confirm_delete_device_body').replaceAll('{name}', name);
  }

  String get confirmDeleteRoomTitle => translate('confirm_delete_room_title');
  String confirmDeleteRoomBody(String name) {
    return translate('confirm_delete_room_body').replaceAll('{name}', name);
  }

  String get confirmDeleteRuleTitle => translate('confirm_delete_rule_title');
  String confirmDeleteRuleBody(String name) {
    return translate('confirm_delete_rule_body').replaceAll('{name}', name);
  }

  String get confirmDeleteSceneTitle => translate('confirm_delete_scene_title');
  String confirmDeleteSceneBody(String name) {
    return translate('confirm_delete_scene_body').replaceAll('{name}', name);
  }

  String get confirmResetDashboardTitle =>
      translate('confirm_reset_dashboard_title');
  String get confirmResetDashboardBody =>
      translate('confirm_reset_dashboard_body');
  String get confirmClearHistoryTitle =>
      translate('confirm_clear_history_title');
  String get confirmClearHistoryBody => translate('confirm_clear_history_body');
  String get confirmClearNotificationsTitle =>
      translate('confirm_clear_notifications_title');
  String get confirmClearNotificationsBody =>
      translate('confirm_clear_notifications_body');

  String get celsius => translate('celsius');
  String get fahrenheit => translate('fahrenheit');
  String get homeAdministrator => translate('home_administrator');
  String get systemDisplayLanguage => translate('system_display_language');
  String get themeDescription => translate('theme_description');
  String get weatherAcDisplay => translate('weather_ac_display');
  String get simulated => translate('simulated');
  String get connect => translate('connect');
  String get wifiNetworkSsid => translate('wifi_network_ssid');
  String get enterWifiSsid => translate('enter_wifi_ssid');
  String get wifiPassword => translate('wifi_password');
  String get enterWifiPassword => translate('enter_wifi_password');
  String get readyToPair => translate('ready_to_pair');
  String get provisionAndConnect => translate('provision_and_connect');
  String get cancelPairing => translate('cancel_pairing');
  String get completeAndDashboard => translate('complete_and_dashboard');
  String get connectingBle => translate('connecting_ble');
  String get configuringWifi => translate('configuring_wifi');
  String get verifyingMqtt => translate('verifying_mqtt');
  String get finalizingConfig => translate('finalizing_config');
  String get deleteRule => translate('confirm_delete_rule_title');
  String get resetDashboardLayout => translate('confirm_reset_dashboard_title');
  String get resetDashboardConfirmBody =>
      translate('confirm_reset_dashboard_body');
  String get clearAllNotifications =>
      translate('confirm_clear_notifications_title');
  String get historyCleared => translate('history_cleared');
  String get notificationsCleared => translate('notifications_cleared');
  String get unread => translate('unread');
  String get scanningForDevices => translate('scanning_for_devices');
  String get devicesFound => translate('devices_found');
  String get pairingTimeoutDesc => translate('pairing_timeout_desc');

  // Phase 8 Privacy, Recovery & Enhanced Backup
  String get privacyCenter => translate('privacy_center');
  String get privacyCenterSubtitle => translate('privacy_center_subtitle');
  String get simulationModeStatus => translate('simulation_mode_status');
  String get simulationModeDesc => translate('simulation_mode_desc');
  String get localStorageTitle => translate('local_storage_title');
  String get localStorageDesc => translate('local_storage_desc');
  String get storageCategories => translate('storage_categories');
  String get storageHealth => translate('storage_health');
  String get storageHealthOptimal => translate('storage_health_optimal');
  String get storageUsageApprox => translate('storage_usage_approx');
  String get lastSavedTime => translate('last_saved_time');
  String get lastSavedNever => translate('last_saved_never');
  String get clearActivityHistory => translate('clear_activity_history');
  String get clearNotifications => translate('clear_notifications');
  String get openRecoveryCenter => translate('open_recovery_center');
  String get openRecoveryCenterDesc => translate('open_recovery_center_desc');
  String get recoveryCenter => translate('recovery_center');
  String get recoverySubtitle => translate('recovery_subtitle');
  String get recoveryRetryLoad => translate('recovery_retry_load');
  String get recoveryRestoreSnapshot => translate('recovery_restore_snapshot');
  String get recoveryCreateSnapshot => translate('recovery_create_snapshot');
  String get recoveryImportBackup => translate('recovery_import_backup');
  String get recoveryFactoryReset => translate('recovery_factory_reset');
  String get recoveryNoSnapshot => translate('recovery_no_snapshot');
  String get recoverySnapshotAvailable =>
      translate('recovery_snapshot_available');
  String get recoveryStateReloaded => translate('recovery_state_reloaded');
  String get recoverySnapshotRestored =>
      translate('recovery_snapshot_restored');
  String get recoverySnapshotCreated => translate('recovery_snapshot_created');
  String get factoryResetWarning => translate('factory_reset_warning');
  String get confirmFactoryReset => translate('confirm_factory_reset');
  String get factoryResetDone => translate('factory_reset_done');
  String get pasteBackupJson => translate('paste_backup_json');
  String get validateAndPreview => translate('validate_and_preview');
  String get secretsSanitized => translate('secrets_sanitized');

  // Phase 9 UI Freeze & Localization Normalization
  String get online => translate('online');
  String get addRoom => translate('add_room');
  String get noRooms => translate('no_rooms');
  String roomAdded(String name) =>
      translate('room_added').replaceAll('{name}', name);
  String roomDeleted(String name) =>
      translate('room_deleted').replaceAll('{name}', name);
  String sceneExecuted(String name) =>
      translate('scene_executed').replaceAll('{name}', name);
  String sceneSaved(String name) =>
      translate('scene_saved').replaceAll('{name}', name);
  String sceneDeleted(String name) =>
      translate('scene_deleted').replaceAll('{name}', name);
  String get addScene => translate('add_scene');
  String get runScene => translate('run_scene');
  String ruleCreated(String name) =>
      translate('rule_created').replaceAll('{name}', name);
  String ruleDeleted(String name) =>
      translate('rule_deleted').replaceAll('{name}', name);
  String get newAutomationRule => translate('new_automation_rule');
  String get saveAutomationRule => translate('save_automation_rule');
  String get ruleDetails => translate('rule_details');
  String deviceDeleted(String name) =>
      translate('device_deleted').replaceAll('{name}', name);
  String get deviceSettingsSaved => translate('device_settings_saved');
  String homeAdded(String name) =>
      translate('home_added').replaceAll('{name}', name);
  String homeDeleted(String name) =>
      translate('home_deleted').replaceAll('{name}', name);
  String get telemetryRefreshed => translate('telemetry_refreshed');
  String get curtainOpen => translate('curtain_open');
  String get curtainStop => translate('curtain_stop');
  String get curtainClose => translate('curtain_close');
  String get pinFavorite => translate('pin_favorite');
  String get unpinFavorite => translate('unpin_favorite');
  String get deviceSettings => translate('device_settings');
  String get presetValid => translate('preset_valid');
  String get presetMalformed => translate('preset_malformed');
  String get presetOversized => translate('preset_oversized');
  String get presetSchemaV7 => translate('preset_schema_v7');
  String get presetDuplicateIds => translate('preset_duplicate_ids');
  String get simulateCorruptedFile => translate('simulate_corrupted_file');
  String get electricityTariffSetting =>
      translate('electricity_tariff_setting');
  String get electricityTariffDesc => translate('electricity_tariff_desc');
  String get resetDemoDesc => translate('reset_demo_desc');
  String get noDevicesAvailableScene => translate('no_devices_available_scene');
  String get pleaseEnterSceneName => translate('please_enter_scene_name');
  String get actionLabel => translate('action_label');
  String get targetDevicesLabel => translate('target_devices_label');
  String get powerAction => translate('power_action');
  String get setBrightnessAction => translate('set_brightness_action');
  String get setTempAction => translate('set_temp_action');
  String get enableConditionCheck => translate('enable_condition_check');
  String get change => translate('change');
  String get addAction => translate('add_action');
  String get advance1Hour => translate('advance_1_hour');
  String get jumpTo0700 => translate('jump_to_0700');
  String get jumpTo2200 => translate('jump_to_2200');
  String get ambientTemp => translate('ambient_temp');
  String get fastForwardJump => translate('fast_forward_jump');
  String get virtualClock => translate('virtual_clock');
  String get ambientControls => translate('ambient_controls');
  String get refreshTelemetry => translate('refresh_telemetry');
  String get exportBackupDesc => translate('export_backup_desc');
  String get backupIntroDesc => translate('backup_intro_desc');
  String get backupValidationFailure => translate('backup_validation_failure');
  String get commandTurnPower => translate('command_turn_power');
  String get commandSetTemp => translate('command_set_temp');
  String get commandSetBrightness => translate('command_set_brightness');
  String get commandOpenCurtain => translate('command_open_curtain');
  String get commandEngageLock => translate('command_engage_lock');
}

/// LocalizationsDelegate for [AppLocalizations].
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
