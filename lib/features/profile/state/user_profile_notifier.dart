import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../../services/storage/home_persistence_manager.dart';

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier([
    UserProfile? initial,
    this._persistenceManager,
  ]) : super(initial ?? HomePersistenceManager.defaultUserProfile);

  final HomePersistenceManager? _persistenceManager;

  void updateProfile(UserProfile profile) {
    state = profile;
    _persist();
  }

  void setLanguage(String lang) {
    state = state.copyWith(language: lang);
    _persist();
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    _persist();
  }

  void setReducedMotion(bool reduced) {
    state = state.copyWith(reducedMotion: reduced);
    _persist();
  }

  void setTemperatureUnit(String unit) {
    state = state.copyWith(temperatureUnit: unit);
    _persist();
  }

  void setAccentColor(int color) {
    state = state.copyWith(accentColor: color);
    _persist();
  }

  void _persist() {
    _persistenceManager?.saveUserProfile(state);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final persistence = ref.watch(homePersistenceProvider);
  final initial = persistence.cachedState?.userProfile ??
      HomePersistenceManager.defaultUserProfile;
  return UserProfileNotifier(initial, persistence);
});
