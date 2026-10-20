# Lumivo — Flutter Smart Home (Phase 0)

A Dark Minimal Smart Home dashboard for everyday users. Phase 0 is an **offline, mock-data-only** prototype — it does not connect to actual IoT devices and is not ready for store submission.

## Requirements (Windows)
- Flutter SDK installed and on PATH (Dart SDK included)
- Android Studio + Android SDK and emulator, or Android device with USB debugging
- VS Code optional

## First run

Open PowerShell in this folder and run:

```powershell
flutter doctor
flutter create --project-name lumivo --org com.example --platforms android,ios .
flutter pub get
flutter run
```

`flutter create` generates the missing native `android/` and `ios/` folders; it does **not** create a built iOS binary on Windows. For iOS compilation/distribution use macOS with Xcode later.

If prompted to choose a device, select an Android emulator or attached Android phone. You can also run `flutter devices` and `flutter run -d <device-id>`.

## Features in this phase
- Dark Minimal dashboard and mobile navigation
- Rooms: Living Room, Bedroom, Kitchen
- Mock temperature/humidity display
- Mock switches for light/fan/security
- Async command confirmation and loading indicator
- Repository abstraction, Riverpod stream, mock source

## Architecture
- `lib/core/models`: shared device and command contracts
- `lib/core/repositories`: transport-agnostic repository interface
- `lib/services/mock`: fake implementation for development
- `lib/features/dashboard`: user interface
- `lib/app`: app bootstrapping and providers

## Planned before public launch
Account/home management, BLE onboarding, secure provisioning, backend authentication, MQTT/TLS, device ownership and recovery, privacy policy, account deletion, telemetry permissions, localization and automated tests.

**Security note:** Never transmit plaintext Wi-Fi credentials over an unauthenticated BLE characteristic. Use authenticated provisioning and per-device identity.
