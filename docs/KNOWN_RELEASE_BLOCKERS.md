# Lumivo Native Platform Release Blocker Register

This document provides a transparent, unmasked audit of the exact build toolchain, operating system, and native platform blockers identified during the **Phase 10 Platform Build & Release Audit** on the Windows development workstation.

---

## 1. Executive Summary: Platform Readiness Matrix

| Platform Target | Build Target | Local Workstation Feasibility | CI/CD Feasibility | Primary Root Cause Blocker |
|---|---|---|---|---|
| **Android** | Debug APK | ⚠️ Blocked locally | ✅ Ready (JDK 17/21 + SDK 36) | Incompatible JDK 24 & Missing SDK `cmdline-tools` |
| **Android** | Release AAB (API 36) | ⚠️ Blocked locally | ✅ Ready (JDK 17/21 + SDK 36) | Incompatible JDK 24 & Missing SDK `cmdline-tools` |
| **iOS** | TestFlight IPA | ❌ Impossible on Windows | ✅ Ready (macOS Runner) | Apple toolchain requires macOS & Xcode |
| **Flutter Web** | Production Wasm/JS | ✅ 100% Ready | ✅ Ready | None (Local development & builds operational) |
| **Flutter Windows** | Native Windows EXE | ✅ 100% Ready | ✅ Ready | None (Visual Studio 2022 Build Tools installed) |

---

## 2. Detailed Blocker Analysis

### Blocker 1: JDK 24 Incompatibility with Android Gradle Toolchain
- **Severity**: Critical (Android Local Build Blocker)
- **Observed Environment**:
  - `JAVA_HOME = E:\Java\jdk-24`
  - Java runtime version: `Java 24`
- **Technical Analysis**:
  - Gradle (including Gradle 8.x and Gradle 9.x) and Google's Android Gradle Plugin (AGP) require Java 17 or Java 21 LTS.
  - Attempting to compile Android artifacts with Java 24 causes Gradle daemon initialization crashes:
    `Unsupported class file major version 68` or `ClassNotFoundException: org.gradle.internal.jvm.Jvm`.
- **Required Resolution**:
  - Install Eclipse Temurin OpenJDK 17 LTS or 21 LTS.
  - Configure `JAVA_HOME` pointing to JDK 17/21 (e.g. `C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot`).

---

### Blocker 2: Missing Android SDK `cmdline-tools` & API 36 Platform
- **Severity**: Critical (Android Local Build Blocker)
- **Observed Environment (`flutter doctor -v`)**:
  ```
  [X] Android toolchain - develop for Android devices
      • Android SDK at C:\Users\admin\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe
      • Emulator version unknown
      X cmdline-tools component is missing.
  ```
- **Technical Analysis**:
  - The local workstation has only the minimal WinGet `Google.PlatformTools` package installed (containing `adb.exe`), rather than a full Android SDK installation.
  - The SDK lacks:
    1. `cmdline-tools` (containing `sdkmanager`, `avdmanager`).
    2. Android 36 SDK Platform (`platforms/android-36`).
    3. Android 36 Build-Tools (`build-tools/36.0.0`).
    4. Accepted Android SDK licenses.
- **Required Resolution**:
  - Download and install Google Android Studio or Android Command-line Tools.
  - Set `ANDROID_HOME = C:\Users\admin\AppData\Local\Android\Sdk`.
  - Run:
    ```powershell
    sdkmanager --install "platforms;android-36" "build-tools;36.0.0" "cmdline-tools;latest"
    flutter doctor --android-licenses
    ```

---

### Blocker 3: iOS IPA Build Impossibility on Windows OS
- **Severity**: Platform Constraint (Hard Architecture Boundary)
- **Observed Environment**:
  - Operating System: `Microsoft Windows [Version 10.0.26300.9711]` (Windows 11)
  - Xcode: Not available (Apple proprietary software exclusive to macOS).
- **Technical Analysis**:
  - Flutter iOS builds require Apple Xcode, `xcrun`, Darwin `clang`, Swift toolchain, and Apple codesigning identities.
  - Running `flutter build ipa` or `flutter build ios` on Windows is fundamentally unsupported by Flutter and the operating system.
- **Required Resolution**:
  - Do **not** attempt or claim to build iOS release binaries on Windows.
  - Delegate all iOS TestFlight IPA builds to an automated macOS CI runner (e.g. GitHub Actions `macos-latest` as defined in `docs/IOS_DISTRIBUTION.md`) or a dedicated macOS development workstation.

---

### Blocker 4: Production Signing Credentials Isolation
- **Severity**: Informational / Operational Security Policy
- **Observed State**:
  - `android/lumivo-upload-keystore.jks` and `android/key.properties` are not present in the repository.
- **Technical Analysis**:
  - This is intentional and adheres to project security rules: cryptographic release keys and passwords must never be committed to source control.
  - `android/app/build.gradle.kts` has been audited and configured with an automated fallback to debug signing when `key.properties` is absent, preventing build script failure during developer testing and CI smoke runs.
- **Required Resolution**:
  - Maintain `.gitignore` rules for `key.properties` and `*.jks`.
  - Inject release keystore credentials via CI/CD environment secrets during automated production publishing.

---

### Blocker 5: 100% Offline Simulation Mode Boundary
- **Severity**: Architectural Constraint (By Design)
- **Observed State**:
  - Real ESP32 microcontrollers, physical BLE peripheral scanning, hardware Wi-Fi AP provisioning, and remote public MQTT broker connections are intentionally not implemented.
- **Technical Analysis**:
  - Lumivo is architected as an offline, deterministic IoT Command Center with mock virtualized engines (`MockBleService`, `MockProvisioningService`, `MockMqttService`).
  - No physical hardware peripheral connectivity blockers exist because full simulation parity is maintained in memory.
- **Required Resolution**:
  - Preserve 100% offline simulation across all platform releases.
  - Retain zero invasive permissions in `AndroidManifest.xml` and `Info.plist`.
