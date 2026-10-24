# iOS Release Checklist & Preparation Guide

This document outlines the step-by-step procedure for preparing, signing, and releasing **Lumivo** to TestFlight and the Apple App Store.

---

## 1. Important Platform Prerequisite: macOS & Xcode

> [!IMPORTANT]
> **iOS builds CANNOT be executed directly on Windows or Linux.**
> 
> Apple's build toolchain (including `clang`, `swiftc`, `actool`, `codesign`, `ibtool`, and the iOS SDK) requires macOS and Apple Xcode command-line tools. All commands in this checklist must be performed on an Apple Silicon or Intel macOS workstation, or via an automated macOS CI/CD runner (e.g., GitHub Actions `macos-latest`, Bitrise, or Codemagic).

---

## 2. Project & Bundle Configuration

| Parameter | Value | Location |
|---|---|---|
| **App Name** | `Lumivo` | `ios/Runner/Info.plist` (`CFBundleDisplayName`, `CFBundleName`) |
| **Bundle Identifier** | `com.lumivo.app` | `ios/Runner.xcodeproj/project.pbxproj` |
| **Minimum iOS Target** | `iOS 14.0+` | `Podfile` & Xcode Deployment Target |
| **Device Family** | iPhone & iPad | Universal layout supported |

### Hardware & Privacy Permissions Audit
Lumivo is a virtualized IoT simulation platform. All device interactions, sensor curves, and automations run entirely through in-memory simulation engines and mock transport layers.
- **Zero Native Permissions**: `ios/Runner/Info.plist` declares **NO** native Bluetooth (`NSBluetoothAlwaysUsageDescription`), Camera (`NSCameraUsageDescription`), or Location (`NSLocationWhenInUseUsageDescription`) permissions.
- This ensures frictionless App Store review without triggering Apple privacy disclosures or unnecessary runtime permission prompts.

---

## 3. macOS Setup & Xcode Signing Configuration

### Step 3.1: Open Project in Xcode
```bash
cd ios
open Runner.xcworkspace
```
*(Do not open `Runner.xcodeproj`; always open `Runner.xcworkspace` after CocoaPods installation).*

### Step 3.2: Configure Signing & Capabilities
1. In Xcode's Project Navigator, select the root **Runner** project.
2. Select the **Runner** target.
3. Click the **Signing & Capabilities** tab.
4. Ensure **Automatically manage signing** is checked (recommended for development and App Store Connect).
5. Select your registered **Apple Developer Team**.
6. Verify **Bundle Identifier** is set to `com.lumivo.app`.
7. Verify Provisioning Profile resolves without errors (e.g. `Xcode Managed Profile`).

---

## 4. Building the Archive for App Store Connect

### Step 4.1: Clean and Prepare
```bash
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
```

### Step 4.2: Build the IPA Archive
Run the Flutter release command:
```bash
flutter build ipa --release
```
This produces an `.xcarchive` and outputs an IPA bundle into `build/ios/archive/` and `build/ios/ipa/`.

### Step 4.3: Validate & Upload to App Store Connect
You can upload via Xcode Organizer or the command line using `altool` / `xcrun notarytool`:

**Option A: Using Xcode Organizer (GUI)**
1. Open Xcode -> **Window** -> **Organizer**.
2. Select the latest Lumivo archive under the **Archives** tab.
3. Click **Validate App**. Once validation succeeds, click **Distribute App**.
4. Choose **App Store Connect** -> **Upload**.

**Option B: Using Command Line (`xcrun`)**
```bash
xcrun altool --validate-app \
  -f build/ios/ipa/Lumivo.ipa \
  -t ios \
  -u "<your-apple-id@email.com>" \
  -p "<app-specific-password>"

xcrun altool --upload-app \
  -f build/ios/ipa/Lumivo.ipa \
  -t ios \
  -u "<your-apple-id@email.com>" \
  -p "<app-specific-password>"
```

---

## 5. App Store Connect Metadata & Screenshot Guidelines

### 5.1 App Metadata
- **App Name**: Lumivo - Smart Home Command Center
- **Subtitle**: Virtualized IoT Automation & Energy
- **Primary Category**: Utilities
- **Secondary Category**: Lifestyle / Developer Tools
- **Keywords**: smart home, iot, home automation, energy analytics, simulation, demo lab, virtual home
- **Support URL**: `https://lumivo.app/support`
- **Privacy Policy URL**: `https://lumivo.app/privacy`

### 5.2 Required Screenshot Dimensions
| Display Target | Resolution | Required Orientation |
|---|---|---|
| **6.9" Super Retina XDR** (iPhone 16 Pro Max) | 1320 x 2868 px | Portrait |
| **6.7" Super Retina XDR** (iPhone 15 Pro Max) | 1290 x 2796 px | Portrait |
| **6.5" Super Retina HD** (iPhone 11 Pro Max / XS Max) | 1242 x 2688 px | Portrait |
| **13" iPad Pro (M4)** | 2064 x 2752 px | Portrait / Landscape |

Screenshots must showcase:
1. **Interactive Dashboard**: Device cards (lights, fan, AC, curtains) with real-time status and quick toggles.
2. **Room Management**: Filter by living room, bedroom, kitchen, and office.
3. **Demo Lab & Virtual Clock**: Time acceleration controls (10x, 60x, 300x) and ambient telemetry.
4. **Energy Analytics**: Power consumption trends, diurnal curves, and simulated cost estimates.
5. **Automation Rules Engine**: Sensor-driven triggers and scene orchestration.

---

## 6. Pre-Submission Verification Checklist

- [ ] App version and build number bumped in `pubspec.yaml` (e.g., `version: 1.0.0+1`).
- [ ] Bundle ID is `com.lumivo.app` across all targets in Xcode.
- [ ] No private or unused CocoaPods pods in `Podfile.lock`.
- [ ] Dark Mode and Light Mode rendering tested on iOS simulator and physical device.
- [ ] Memory leaks and lifecycle suspension verified on backgrounding (TestFlight internal build).
