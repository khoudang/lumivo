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
