# Lumivo multi-agent collaboration

Product: consumer Smart Home (not a developer-only ESP32 debugger).
UX: onboarding without requiring knowledge of MQTT, BLE, ports, IP addresses or firmware.

Contracts are frozen in Phase 0:
- `lib/core/models/**`
- `lib/core/repositories/**`
- `lib/app/providers.dart` until integrator assigns ownership
- `pubspec.yaml`, `lib/main.dart`: integrator only

Agent UI owns `lib/features/dashboard/presentation/**`, `lib/core/theme/**`.
Agent IoT owns `lib/services/mqtt/**`, `lib/services/ble/**` (future phase).
Agent State owns `lib/services/mock/**` and viewmodel (future phase).

Do not merge code that bypasses repository interfaces or claims local demo data is real hardware state. Never hardcode credentials or broker tokens.
