# Lumivo iOS Platform Distribution & TestFlight Release Guide

This document defines the production release process, macOS CI/CD pipeline, and App Store Connect / TestFlight deployment procedures for **Lumivo iOS**, targeting **Xcode 26+ and iOS 26 SDK** environments.

---

## 1. Specification & Target Architecture Summary

| Configuration Property | Specification / Value | File Location | Purpose & Mandate |
|---|---|---|---|
| **Bundle Identifier** | `com.lumivo.app` | `ios/Runner.xcodeproj/project.pbxproj` | Unique Apple App Store application identifier |
| **Display Name** | `Lumivo` | `ios/Runner/Info.plist` (`CFBundleDisplayName`) | Title shown below icon on iOS home screen |
| **Bundle Name** | `Lumivo` | `ios/Runner/Info.plist` (`CFBundleName`) | System-level bundle short name |
| **Minimum iOS Target** | `iOS 14.0+` | Xcode Project Deployment Target / Podfile | Baseline compatibility for modern SwiftUI/Flutter |
| **Target SDK / Toolchain** | `iOS 26 SDK / Xcode 26+` | macOS CI & Build Environment | Apple App Store 2026 distribution mandate |
| **Export Compliance** | `ITSAppUsesNonExemptEncryption = false` | `ios/Runner/Info.plist` | Automates TestFlight export compliance verification |
| **Supported Devices** | Universal (iPhone & iPad) | `ios/Runner.xcodeproj` | Adaptive responsive layout |
| **Orientations** | Portrait, LandscapeLeft, LandscapeRight | `ios/Runner/Info.plist` | Supported device rotations |

---

## 2. Platform Constraint: macOS Build Exclusivity

> [!CAUTION]
> **iOS IPA compilation is strictly unsupported on Windows or Linux workstations.**
> 
> Apple's build toolchain (`clang`, `swiftc`, `actool`, `ibtool`, `codesign`, `altool`, and the proprietary iOS SDK headers) runs exclusively on macOS. 
> Attempting to execute `flutter build ipa` or `flutter build ios` on Windows will immediately exit with:
> ```
> "Building for iOS is not supported on Windows."
> ```
> All production archive, codesigning, and TestFlight upload operations must be executed either:
> 1. On an Apple Silicon (M1/M2/M3/M4) macOS development workstation.
> 2. Via an automated macOS CI/CD runner (e.g. GitHub Actions `macos-14` / `macos-latest`, Codemagic, or Bitrise).

---

## 3. Privacy & Native Permissions Audit

Lumivo operates as a **100% offline, deterministic simulation platform**:
- **Zero Sensitive Usage Descriptions**: `ios/Runner/Info.plist` intentionally omits `NSBluetoothAlwaysUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, and `NSMicrophoneUsageDescription`.
- **App Store Review Fast-Path**: Because no hardware or background tracking permissions are declared, Lumivo does not require special entitlement justification forms or Apple App Privacy declaration escalations.
- **Privacy Manifest (`PrivacyInfo.xcprivacy`)**: Lumivo does not track users (`NSPrivacyTracking = false`) and local storage is used solely for on-device app state.

---

## 4. Local Build & Archive Procedure (macOS Workstation)

### Step 4.1: Environment Verification
Verify that the macOS machine has Xcode 26+ installed and active:
```bash
xcode-select -p
# Expected: /Applications/Xcode.app/Contents/Developer
xcrun --version
flutter doctor -v
```

### Step 4.2: Dependency Resolution & Pod Installation
```bash
cd /path/to/lumivo
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
```

### Step 4.3: Compiling Release IPA Archive
Run the Flutter IPA build command with release configuration:
```bash
flutter build ipa --release
```
This performs:
1. Flutter AOT compile of Dart code for `arm64`.
2. Xcode `Runner.xcworkspace` archive generation at `build/ios/archive/Runner.xcarchive`.
3. Export of the signed `.ipa` file to `build/ios/ipa/Lumivo.ipa`.

---

## 5. Automated macOS CI/CD Workflow (GitHub Actions)

Below is the production-ready GitHub Actions workflow for building and distributing Lumivo to TestFlight on tagged releases:

```yaml
name: iOS Distribution & TestFlight

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch:

jobs:
  build-and-deploy-ios:
    runs-on: macos-latest
    timeout-minutes: 60

    steps:
      - name: Checkout Codebase
        uses: actions/checkout@v4

      - name: Setup Java (for Gradle / cross-platform scripts)
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.47.7'
          channel: 'stable'
          cache: true

      - name: Install Apple Certificate and Provisioning Profile
        env:
          BUILD_CERTIFICATE_BASE64: ${{ secrets.APPLE_CERTIFICATE_BASE64 }}
          P12_PASSWORD: ${{ secrets.APPLE_P12_PASSWORD }}
          BUILD_PROVISION_PROFILE_BASE64: ${{ secrets.APPLE_PROVISION_PROFILE_BASE64 }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

          echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o $RUNNER_TEMP/build_cert.p12
          security import $RUNNER_TEMP/build_cert.p12 -k $KEYCHAIN_PATH -P "$P12_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo -n "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode -o ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Install CocoaPods Dependencies
        run: |
          flutter pub get
          cd ios
          pod install --repo-update
          cd ..

      - name: Build IPA (TestFlight / App Store Release)
        run: |
          flutter build ipa --release \
            --export-options-plist=ios/ExportOptions.plist

      - name: Upload to TestFlight / App Store Connect
        env:
          APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_PRIVATE_KEY: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
        run: |
          xcrun altool --upload-app \
            -f build/ios/ipa/*.ipa \
            -t ios \
            --apiKey "$APP_STORE_CONNECT_KEY_ID" \
            --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

---

## 6. TestFlight Distribution & Internal Testing Flow

1. **Upload Processing**: Once uploaded via `altool` or Xcode Organizer, App Store Connect processes the binary (typically 5 to 15 minutes).
2. **Export Compliance Auto-Approval**: Because `ITSAppUsesNonExemptEncryption` is set to `<false/>` in `Info.plist`, the build bypasses the export compliance modal and immediately becomes available for testing.
3. **Internal Testing Group**:
   - Add developers and QA testers to the **Lumivo Internal Testers** group.
   - Internal testers receive immediate access without Apple Beta App Review.
4. **External Beta Testing**:
   - For public TestFlight links, submit the build for Beta App Review with release notes:
     *"Lumivo Smart Home Command Center: Offline IoT virtualized telemetry, energy analytics, and automation engine."*
   - Review typically completes in under 24 hours.

---

## 7. App Store Connect Submission Checklist

### 7.1 Metadata & Copy
- **App Name**: `Lumivo - Smart Home Command Center`
- **Subtitle**: `Virtualized IoT Automation & Energy`
- **Bundle ID**: `com.lumivo.app`
- **Primary Category**: `Utilities`
- **Secondary Category**: `Lifestyle`
- **Content Rights**: Does not contain, show, or access third-party content.
- **Age Rating**: 4+ (No unrestricted web access, no gambling, no mature content).

### 7.2 Screenshot Specifications
| Display Target | Resolution | Orientation | Required Views |
|---|---|---|---|
| **6.9" Super Retina XDR** (iPhone 16 Pro Max) | 1320 x 2868 px | Portrait | Main Dashboard, Room Filters |
| **6.7" Super Retina XDR** (iPhone 15 Pro Max) | 1290 x 2796 px | Portrait | Energy Analytics, Automation Editor |
| **6.5" Super Retina HD** (iPhone 11 Pro Max / XS Max) | 1242 x 2688 px | Portrait | Demo Lab & Virtual Clock Speed controls |
| **13" iPad Pro (M4)** | 2064 x 2752 px | Portrait & Landscape | Split-view dashboard & full telemetry chart |

### 7.3 Release Decision
- Choose **Manually release this version** or **Automatically release this version after App Store review**.
