import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 10: Platform Configuration & Release Audit', () {
    test('Android build.gradle.kts enforces targetSdk 36 and compileSdk 36',
        () {
      final file = File('android/app/build.gradle.kts');
      expect(file.existsSync(), isTrue,
          reason: 'android/app/build.gradle.kts must exist');

      final content = file.readAsStringSync();

      // Verify compileSdk = 36
      final compileSdkRegex = RegExp(r'compileSdk\s*=\s*(\d+)');
      final compileSdkMatch = compileSdkRegex.firstMatch(content);
      expect(compileSdkMatch, isNotNull,
          reason: 'compileSdk must be explicitly defined');
      final compileSdkValue = int.parse(compileSdkMatch!.group(1)!);
      expect(compileSdkValue, greaterThanOrEqualTo(36),
          reason: 'compileSdk must be at least 36 for 2026 Android releases');

      // Verify targetSdk = 36
      final targetSdkRegex = RegExp(r'targetSdk\s*=\s*(\d+)');
      final targetSdkMatch = targetSdkRegex.firstMatch(content);
      expect(targetSdkMatch, isNotNull,
          reason: 'targetSdk must be explicitly defined');
      final targetSdkValue = int.parse(targetSdkMatch!.group(1)!);
      expect(targetSdkValue, greaterThanOrEqualTo(36),
          reason: 'targetSdk must be 36 for Google Play 2026 mandates');

      // Verify namespace & applicationId
      expect(content, contains('namespace = "com.lumivo.app"'));
      expect(content, contains('applicationId = "com.lumivo.app"'));

      // Verify minSdk
      final minSdkRegex = RegExp(r'minSdk\s*=\s*(\d+)');
      final minSdkMatch = minSdkRegex.firstMatch(content);
      expect(minSdkMatch, isNotNull);
      final minSdkValue = int.parse(minSdkMatch!.group(1)!);
      expect(minSdkValue, inInclusiveRange(21, 26));

      // Verify Java 17 compatibility
      expect(content, contains('JavaVersion.VERSION_17'));
      expect(
          content,
          contains(
              'jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17'));

      // Verify release signing fallback logic
      expect(content, contains('keystorePropertiesFile.exists()'));
      expect(content, contains('signingConfigs.getByName("release")'));
      expect(content, contains('signingConfigs.getByName("debug")'));
    });

    test(
        'Android main AndroidManifest.xml maintains offline simulation and Lumivo branding',
        () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue,
          reason: 'android/app/src/main/AndroidManifest.xml must exist');

      final content = file.readAsStringSync();

      // App Label
      expect(content, contains('android:label="Lumivo"'),
          reason: 'Android app label must be "Lumivo"');

      // Main Activity
      expect(content, contains('android:name=".MainActivity"'));
      expect(content, contains('android.intent.action.MAIN'));
      expect(content, contains('android.intent.category.LAUNCHER'));

      // Strict check: No invasive native hardware permissions for 100% offline simulation
      final prohibitedPermissions = [
        'android.permission.BLUETOOTH_SCAN',
        'android.permission.BLUETOOTH_CONNECT',
        'android.permission.BLUETOOTH_ADVERTISE',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.ACCESS_BACKGROUND_LOCATION',
        'android.permission.CAMERA',
        'android.permission.RECORD_AUDIO',
      ];

      for (final permission in prohibitedPermissions) {
        expect(content, isNot(contains(permission)),
            reason:
                'AndroidManifest.xml must not declare invasive permission: $permission');
      }
    });

    test(
        'iOS Info.plist conforms to bundle specifications and offline privacy standards',
        () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue,
          reason: 'ios/Runner/Info.plist must exist');

      final content = file.readAsStringSync();

      // Display and Bundle Names
      expect(
          content,
          contains(
              '<key>CFBundleDisplayName</key>\n\t<string>Lumivo</string>'));
      expect(content,
          contains('<key>CFBundleName</key>\n\t<string>Lumivo</string>'));
      expect(
          content,
          contains(
              '<key>CFBundleIdentifier</key>\n\t<string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>'));

      // Export Compliance
      expect(content,
          contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>'),
          reason:
              'ITSAppUsesNonExemptEncryption should be false for seamless TestFlight distribution');

      // Interface Orientations
      expect(content, contains('UIInterfaceOrientationPortrait'));
      expect(content, contains('UIInterfaceOrientationLandscapeLeft'));
      expect(content, contains('UIInterfaceOrientationLandscapeRight'));

      // Strict check: No sensitive usage descriptions in offline simulation
      final prohibitedKeys = [
        'NSBluetoothAlwaysUsageDescription',
        'NSBluetoothPeripheralUsageDescription',
        'NSLocationWhenInUseUsageDescription',
        'NSLocationAlwaysUsageDescription',
        'NSCameraUsageDescription',
        'NSMicrophoneUsageDescription',
      ];

      for (final key in prohibitedKeys) {
        expect(content, isNot(contains('<key>$key</key>')),
            reason:
                'iOS Info.plist must not declare sensitive usage description: $key');
      }
    });

    test('iOS Runner.xcodeproj defines com.lumivo.app bundle identifier', () {
      final file = File('ios/Runner.xcodeproj/project.pbxproj');
      expect(file.existsSync(), isTrue,
          reason: 'ios/Runner.xcodeproj/project.pbxproj must exist');

      final content = file.readAsStringSync();
      expect(content, contains('PRODUCT_BUNDLE_IDENTIFIER = com.lumivo.app;'),
          reason:
              'Xcode project must define com.lumivo.app as PRODUCT_BUNDLE_IDENTIFIER');
    });

    test('Platform distribution documentation is complete and verified', () {
      final androidDoc = File('docs/ANDROID_DISTRIBUTION.md');
      expect(androidDoc.existsSync(), isTrue,
          reason: 'docs/ANDROID_DISTRIBUTION.md must exist');
      final androidContent = androidDoc.readAsStringSync();
      expect(androidContent, contains('Target SDK'));
      expect(androidContent, contains('36'));
      expect(androidContent, contains('JDK 17'));
      expect(androidContent, contains('keytool'));
      expect(androidContent, contains('flutter build appbundle --release'));

      final iosDoc = File('docs/IOS_DISTRIBUTION.md');
      expect(iosDoc.existsSync(), isTrue,
          reason: 'docs/IOS_DISTRIBUTION.md must exist');
      final iosContent = iosDoc.readAsStringSync();
      expect(iosContent, contains('com.lumivo.app'));
      expect(iosContent, contains('Xcode 26+'));
      expect(iosContent, contains('iOS 26 SDK'));
      expect(iosContent, contains('TestFlight'));
      expect(iosContent, contains('macOS'));

      final blockerDoc = File('docs/KNOWN_RELEASE_BLOCKERS.md');
      expect(blockerDoc.existsSync(), isTrue,
          reason: 'docs/KNOWN_RELEASE_BLOCKERS.md must exist');
      final blockerContent = blockerDoc.readAsStringSync();
      expect(blockerContent, contains('jdk-24'));
      expect(blockerContent, contains('cmdline-tools'));
      expect(blockerContent, contains('Windows'));
    });
  });
}
