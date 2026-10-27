# Lumivo Android Platform Distribution & Production Release Guide

This document provides the definitive, production-ready release specification and build instructions for **Lumivo** on the Android platform, targeting **API Level 36 (Android 16)** in full compliance with Google Play Store 2026 distribution mandates.

---

## 1. Specification & Target Architecture Summary

| Configuration Property | Specification / Value | File Location | Purpose & Mandate |
|---|---|---|---|
| **Namespace** | `com.lumivo.app` | `android/app/build.gradle.kts` | Native Android Kotlin namespace |
| **Application ID** | `com.lumivo.app` | `android/app/build.gradle.kts` | Unique Google Play application identifier |
| **Compile SDK** | `36` (Android 16) | `android/app/build.gradle.kts` | Compilation against latest Android 16 APIs |
| **Target SDK** | `36` (Android 16) | `android/app/build.gradle.kts` | Google Play Store 2026 requirement |
| **Minimum SDK** | `21` (Android 5.0 Lollipop) | `android/app/build.gradle.kts` | Compatibility across legacy & modern devices |
| **JVM Target** | Java 17 (`JVM_17`) | `android/app/build.gradle.kts` | Gradle / Kotlin bytecode compatibility |
| **App Name** | `Lumivo` | `android/app/src/main/AndroidManifest.xml` | Display title on Android Launcher |
| **Distribution Format** | Android App Bundle (`.aab`) | `build/app/outputs/bundle/release/` | Google Play Dynamic Delivery requirement |

---

## 2. Security & Hardware Permissions Audit

Lumivo is architected as an **architectural simulation-first IoT Command Center**. All device communications, telemetry polling, state transitions, and automations are executed deterministically in-memory by virtualized mock services (`MockBleService`, `MockProvisioningService`, `MockMqttService`).

### Zero Sensitive Permissions Declaration
- **No Bluetooth Scopes**: Lumivo does **not** declare `android.permission.BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, or `BLUETOOTH_ADVERTISE`.
- **No Location Tracking**: Lumivo does **not** declare `android.permission.ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, or `ACCESS_BACKGROUND_LOCATION`.
- **No Sensor / Camera / Mic Scopes**: No camera, microphone, or biometric native permissions are included.
- **Google Play Submission Advantage**: Because zero sensitive hardware or location permissions are declared, Lumivo bypasses intrusive Google Play permissions declaration declarations, sensitive data disclosure forms, and associated review delays.
- **Offline Integrity**: Production builds operate 100% offline without mandatory remote cloud dependencies.

---

## 3. Toolchain Prerequisites & Diagnosis

### 3.1 Recommended Java Development Kit (JDK 17 or JDK 21 LTS)
> [!IMPORTANT]
> **Gradle 8.x and 9.x require Java 17 or Java 21 LTS.**
> Do **NOT** use Java 24 (`E:\Java\jdk-24` or other early-access/bleeding-edge JDKs) for native Gradle Android builds. Java 24 introduces bytecode incompatibilities with Gradle worker daemons (`Unsupported class file major version` errors).

#### Setting the Recommended JDK on Windows
Download and install Eclipse Temurin OpenJDK 17 or 21 LTS:
```powershell
# Set JAVA_HOME to a verified LTS installation (e.g. Temurin 17 or 21)
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

# Verify Java version
java -version
```

### 3.2 Android SDK & Command-Line Tools
To compile with `targetSdk = 36` and `compileSdk = 36`, the following Android SDK packages must be installed via `sdkmanager` (or Android Studio SDK Manager):
```powershell
# Install Android 36 SDK Platform and Build-Tools
sdkmanager --install "platforms;android-36"
sdkmanager --install "build-tools;36.0.0"
sdkmanager --install "cmdline-tools;latest"
sdkmanager --install "platform-tools"
```

---

## 4. Keystore Generation & Secret Management

Release binaries uploaded to Google Play must be signed with a production upload key.

### 4.1 Generating the Upload Keystore
Generate a 2048-bit (or 4096-bit) RSA keystore using Java's `keytool`:

#### PowerShell (Windows):
```powershell
keytool -genkeypair -v `
  -keystore lumivo-upload-keystore.jks `
  -alias lumivo-upload-key `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -storetype JKS `
  -dname "CN=Lumivo Release, OU=Mobile Engineering, O=Lumivo IoT, L=Ho Chi Minh City, ST=Vietnam, C=VN"
```

#### Bash / Zsh (macOS / Linux):
```bash
keytool -genkeypair -v \
  -keystore lumivo-upload-keystore.jks \
  -alias lumivo-upload-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storetype JKS \
  -dname "CN=Lumivo Release, OU=Mobile Engineering, O=Lumivo IoT, L=Ho Chi Minh City, ST=Vietnam, C=VN"
```

> [!CAUTION]
> **Store the keystore file and its passwords in a secure password manager or key vault.**
> Never commit `lumivo-upload-keystore.jks` or `key.properties` into Git repository!

### 4.2 Configuring `android/key.properties`
Create a `key.properties` file inside the `android/` directory:
```properties
storePassword=YOUR_STRONG_STORE_PASSWORD
keyPassword=YOUR_STRONG_KEY_PASSWORD
keyAlias=lumivo-upload-key
storeFile=../lumivo-upload-keystore.jks
```

*Note on Safety Fallback:*
Our `android/app/build.gradle.kts` automatically inspects whether `key.properties` exists. If present, it binds the release signing configuration; if absent, it falls back to debug signing to enable frictionless local development and CI testing.

---

## 5. Compiling Android Distribution Artifacts

### 5.1 Compiling the Google Play Android App Bundle (AAB)
The Android App Bundle is the required distribution format for all releases on Google Play:
```powershell
# In project root:
flutter clean
flutter pub get
flutter build appbundle --release
```
**Artifact Output Location:**
```
build/app/outputs/bundle/release/app-release.aab
```

### 5.2 Compiling Standalone Universal Release APK (Sideload / Internal Alpha)
For direct sideloading or internal distribution outside Google Play:
```powershell
flutter build apk --release
```
**Artifact Output Location:**
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Release Verification & Integrity Checks

### 6.1 Validating Signature with `apksigner`
Confirm that the compiled artifact is properly signed and verifies against the target platform:
```powershell
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```
Expected output:
- `Verifies: YES`
- `Signer #1 certificate DN: CN=Lumivo Release, ...`
- `Digest algorithm: SHA-256`

### 6.2 Validating Package Name and Target SDK with `aapt2`
```powershell
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | Select-String "targetSdkVersion|package:"
```
Expected output:
- `package: name='com.lumivo.app'`
- `targetSdkVersion:'36'`

---

## 7. Google Play Console Release Flow

1. **Google Play App Signing**: Enroll the app in Google Play App Signing so Google generates optimized split APKs per device architecture (arm64-v8a, armeabi-v7a, x86_64).
2. **Internal Testing Track**:
   - Create a release in the **Internal Testing** track.
   - Upload `app-release.aab`.
   - Inspect the **Pre-launch report** (verifies device compatibility, zero crashes, and ANR benchmarks).
3. **Store Listing Assets**:
   - App Icon: 512 x 512 px 32-bit PNG.
   - Feature Graphic: 1024 x 500 px JPG or 24-bit PNG.
   - Phone Screenshots: Minimum 4 screenshots (1080 x 2400 px or 1440 x 3200 px).
   - 7-inch & 10-inch Tablet Screenshots: Minimum 1 screenshot each.
4. **App Content & Data Safety**:
   - Category: Lifestyle / Utilities.
   - Target Age: 13+.
   - Data Safety: Declare that **No user data is collected or shared** (100% offline simulation, local storage only).
5. **Rollout Promotion**: Internal Testing $\rightarrow$ Closed Testing (Alpha/Beta) $\rightarrow$ Production.
