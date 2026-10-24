# Android Release & Signing Guide

This guide details the procedure for generating release keys, configuring build signatures, and compiling production Android artifacts (APK & AAB) for **Lumivo**.

---

## 1. Application Identifier & Configuration Summary

| Property | Value | Source File |
|---|---|---|
| **Namespace** | `com.lumivo.app` | `android/app/build.gradle.kts` |
| **Application ID** | `com.lumivo.app` | `android/app/build.gradle.kts` |
| **Minimum SDK** | `21` (Android 5.0 Lollipop) | `android/app/build.gradle.kts` |
| **Target SDK** | `34` (Android 14) | `android/app/build.gradle.kts` |
| **App Name** | `Lumivo` | `android/app/src/main/AndroidManifest.xml` |

### Permissions & Security Notice
Lumivo is an architectural, simulation-first IoT platform. 
- It does **not** declare native Bluetooth scanning, coarse/fine location, or Wi-Fi scanning permissions in `AndroidManifest.xml`.
- No sensitive Google Play permissions declarations or declaration forms are required during store console submission.

---

## 2. Generating the Upload Keystore

Generate a cryptographic release upload keystore using the Java JDK `keytool` utility.

### On Windows (PowerShell)
```powershell
keytool -genkey -v `
  -keystore lumivo-upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias lumivo-upload-key
```

### On macOS / Linux (Bash / Zsh)
```bash
keytool -genkey -v \
  -keystore lumivo-upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias lumivo-upload-key
```

During keystore creation:
1. Enter a secure password for the keystore and the key alias.
2. Provide organization information (e.g. Lumivo Team).
3. Securely store `lumivo-upload-keystore.jks` in a secure vault or offline backup. **Do not commit keystore files to source control.**

---

## 3. Configuring `key.properties`

Create a file named `key.properties` inside the `android/` directory (i.e. `android/key.properties`).

> [!WARNING]
> Ensure `android/key.properties` is listed in `.gitignore` and never checked into Git repositories.

Add the following configuration to `android/key.properties`:

```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=lumivo-upload-key
storeFile=../lumivo-upload-keystore.jks
```

*Note:* If you placed `lumivo-upload-keystore.jks` in the root of the project, use `storeFile=../../lumivo-upload-keystore.jks`. If placed directly inside `android/app/`, use `storeFile=lumivo-upload-keystore.jks`.

Our `android/app/build.gradle.kts` automatically detects `key.properties`:
- When present, it signs release builds using your release keystore.
- When absent, it safely falls back to debug signing to allow developers to build and test locally without errors.

---

## 4. Building Android Artifacts

### 4.1 Debug APK (Development & Sideloading)
To build a fast debug APK for local testing on a connected Android device or emulator:
```bash
flutter build apk --debug
```
- Output location: `build/app/outputs/flutter-apk/app-debug.apk`

### 4.2 Release APK (Direct Device Installation)
To produce a standalone, optimized release APK (useful for internal alpha testing or sideload distribution):
```bash
flutter build apk --release
```
- Output location: `build/app/outputs/flutter-apk/app-release.apk`

### 4.3 Production Android App Bundle (Google Play Store)
Google Play requires the **Android App Bundle (.aab)** format for all new apps. The App Bundle allows Google Play to generate device-specific optimized APKs with dynamic delivery:
```bash
flutter build appbundle --release
```
- Output location: `build/app/outputs/bundle/release/app-release.aab`

---

## 5. Verifying the Release Build Signature

You can verify that the generated APK or App Bundle is correctly signed with `com.lumivo.app` and your release certificate:

```bash
# Using apksigner from Android SDK build-tools
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Look for:
- `Signer #1 certificate DN: CN=Lumivo, ...`
- `Verifies: YES`
- `Package Name: com.lumivo.app`

---

## 6. Google Play Console Deployment Checklist

1. **Create Application**: In Google Play Console, select **Create app**, set name to **Lumivo**, and choose Default language.
2. **App Integrity / Play App Signing**: Ensure Google Play App Signing is enabled (uses your upload keystore).
3. **Internal Testing Track**: Create a new release in the **Internal Testing** track and upload `app-release.aab`.
4. **Target Audience & Content**: Confirm Target Age (13+) and category (Lifestyle/Tools).
5. **Rollout**: Promote from Internal Testing -> Closed Testing -> Production.
