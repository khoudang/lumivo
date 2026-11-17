import 'package:flutter_test/flutter_test.dart';
import 'package:lumivo/core/models/user_profile.dart';
import 'package:lumivo/services/storage/home_persistence_manager.dart';
import 'package:lumivo/services/storage/native_storage_path_resolver.dart';

void main() {
  test('fresh home defaults to calm light without changing saved themes', () {
    expect(HomePersistenceManager.defaultUserProfile.themeMode, 'light');
    for (final mode in ['dark', 'oled']) {
      final saved = HomePersistenceManager.defaultUserProfile
          .copyWith(themeMode: mode)
          .toJson();
      expect(UserProfile.fromJson(saved).themeMode, mode);
    }
  });

  for (final platform in ['android', 'ios']) {
    test('$platform launch retains legacy memory fallback until path bootstrap',
        () {
      expect(
          NativeStoragePathResolver.resolve(
            operatingSystem: platform,
            environment: const {},
          ),
          isNull);
      expect(
          NativeStoragePathResolver.resolve(
            operatingSystem: platform,
            environment: const {
              'LUMIVO_STORAGE_PATH': '/isolated/qa/storage.json'
            },
          ),
          '/isolated/qa/storage.json');
    });
  }
}
