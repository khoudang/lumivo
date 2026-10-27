# Changelog

All notable changes to the Lumivo Smart Home project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0-rc.1] - 2026-10-27 (Phase 10: Final Testing & Distribution Validation)

### Added
- **Phase 10 Release Validation Suite** (`test/unit/phase10_release_validation_test.dart`):
  - Strict version check verifying exact `1.0.0-rc.1` across exported metadata and backup payloads.
  - Memory-bounded buffer stress tests for `CommandPipeline`, `DefaultEnergyAnalyticsService`, and `HomePersistenceManager`.
  - Process cold restart simulation verifying 100% state persistence across homes, rooms, devices, scenes, automations, and configurations.
  - Simulation process lifecycle management (`SimulationLifecycleObserver`) with background suspension and deterministic virtual clock resynchronization.
  - Comprehensive security audit covering recursive credential sanitization across 14+ key patterns and CWE-1236 CSV injection protection.
  - Strict multi-home isolation validation preventing cross-boundary data leaks.
  - 100% offline determinism guarantee with zero external network or socket dependencies.
- **17 Critical User Journeys Final Acceptance Suite** (`test/widget/phase10_final_acceptance_test.dart`):
  - End-to-end automated coverage for all 17 CUJs:
    1. Welcome & Demo mode onboarding.
    2. Multi-Home management & boundary isolation.
    3. Room management & dynamic filtering.
    4. Device discovery & BLE provisioning flow.
    5. Comprehensive multi-type device controls (Light, AC, Lock, Socket).
    6. Coordinated scene execution & timeline activity logging.
    7. Automation rule evaluation & loop protection guard.
    8. Offline simulation & reconnection storm recovery.
    9. Energy telemetry breakdown & RFC-4180 CSV export.
    10. Safe backup export with exact `1.0.0-rc.1` version and secret scrubbing.
    11. Safe backup restore preview & atomic transactional rollback on corruption.
    12. Recovery Center health diagnostics & snapshot restoration.
    13. Privacy Center local storage audit & zero remote telemetry guarantee.
    14. Bilingual localization parity across primary surfaces (EN/VI).
    15. Accessibility compliance (WCAG 2.1 AA touch targets >= 48dp, Semantics & 2.0x font scaling).
    16. Ultra-narrow mobile responsiveness (320x600 viewport across 8 primary screens).
    17. App lifecycle transitions, bounded memory stability & cold restart persistence.
- **Phase 10 Final QA Report & Release Documentation** (`docs/PHASE10_FINAL_REPORT.md`, `docs/FINAL_RELEASE_CHECKLIST.md`):
  - Comprehensive release qualification sign-off covering all 614 automated tests (100% pass rate).
  - Explicit platform release status matrix:
    - Web Demo Release: **PASS** (100% offline, production build ready).
    - Android Internal Beta: **BLOCKED** (Toolchain constraint: JDK 24 incompatibility + missing Android SDK cmdline-tools).
    - iOS TestFlight Readiness: **BLOCKED** (Host environment constraint: requires macOS / Xcode toolchain).
    - Public Stores (Google Play / App Store): **NOT SUBMITTED** (Pending beta resolution and portal provisioning).

### Changed
- Hardened all version matchers across the entire test suite to require exact `1.0.0-rc.1` matching.
- Expanded total test coverage to 614 tests across unit, widget, service, and performance suites with zero failures and zero flakes.

---

## [1.0.0-rc.1] - 2026-10-27 (Phase 9: Release Candidate & UX Freeze)

### Added
- **Large-Scale Simulation Benchmark Suite** (`test/performance/phase9_release_performance_test.dart`):
  - 100 devices across 20 rooms, 100 automation rules, and 1,000 activity events.
  - Sub-50ms device repository query latency benchmark.
  - Sub-20ms room filtering latency benchmark across 20 distinct rooms.
  - Virtual clock acceleration verification under 10x, 60x, and 300x multipliers.
  - Memory bounded buffer tests guaranteeing leak-free telemetry and command dispatch.
  - Multi-attribute search and sorting benchmark (< 30ms).
  - Energy insights computation and RFC-4180 CSV generation benchmark (< 25ms).
  - Clean observer and repository lifecycle teardown verification.
- **O(1) Device Index Cache** in `MockDeviceRepository`:
  - Instantaneous ID lookup (`getDeviceById`) and room querying (`getDevicesForRoom`).
  - Automatic index invalidation and rebuild on bulk mutations.
- **Bounded Telemetry Buffers** across simulation services:
  - `CommandPipeline`: `_completedResults` and `_cancelledRequestIds` capped to `2 * maxHistoryEntries` to prevent memory creep in long-running sessions.
  - `DefaultEnergyAnalyticsService`: hard memory cap on sample histories (`maxStoredSamples = 5000`, `maxStoredDeviceSamples = 10000`).
  - `AutomationEngine`: cached rule triggers, hysteresis states, and minutes pruned on rule changes and disposal.
- **Disposal Introspection**:
  - Expose `isDisposed` getters on `VirtualClock`, `SimulationEngine`, and `AutomationEngine`.
- **Release Documentation** (`docs/PHASE9_RELEASE_ENGINEERING.md`):
  - Complete build steps, Web bundle analysis, dependency inventory, and performance benchmark records.

### Changed
- Production Web build audited and verified with canvaskit and Wasm dry run compatibility.
- Cupertino icons and Material icons tree-shaken by > 98% reduction for Web distribution.
- Standardized backup export metadata version to `1.0.0-rc.1`.

### Fixed
- Fixed unbounded memory retention in long-running `CommandPipeline` execution histories.
- Sealed stream controller and subscription disposals in `SimulationEngine` and `SimulationLifecycleObserver`.

---

## [0.8.0] - 2026-10-27 (Phase 8: Privacy Center, Security Hardening & Safe Backup Validation)

### Added
- **Privacy Center & Local Data Management**:
  - Offline-first local data inspection, clear cache, factory reset with double confirmation.
  - Safe Backup Preview with pre-restore structural validation and entity counts.
- **Strict Backup Validation** (`BackupValidationService`):
  - Multi-tier validation against corrupted, tampered, oversized (> 5MB), or malicious JSON payloads.
  - Entity bounding: max 500 devices, 100 rooms, 200 scenes, 200 automations, 500 events.
  - JSON recursion depth limit (10 levels) and string length clamps (128 chars).
- **Atomic Backup Restore with Rollback Protection**:
  - Snapshot-before-restore rollback guaranteeing zero data loss on parsing or schema failure.
  - Concurrency lock preventing race conditions during active restore.
- **CSV Formula Injection Defense (CWE-1236)**:
  - Sanitization of exported CSV cells starting with `=, +, -, @, \t, \r` with single-quote escaping.
- **Recovery Center**:
  - In-app diagnostic recovery screen for state reset and integrity repairs.
- **Phase 8 Security Test Matrix & Acceptance Suite** (Flows A-N).

---

## [0.7.0] - 2026-10-27 (Phase 7: System Audit, Security & Persistence Hardening)

### Added
- **Multi-Home Data Isolation**:
  - Strict isolation ensuring devices, rooms, scenes, and automations never bleed across home boundaries.
- **Accessibility & UX Audit**:
  - WCAG AA compliant 48x48dp minimum touch targets.
  - High-contrast text scaling and screen reader accessibility labels (`Semantics`).
- **Destructive Action Confirmations**:
  - Explicit modal confirmation dialogs for device removal, room deletion, and home switching.
- **Persistence Integrity & Bounded Buffers**:
  - Bounded activity events and command records capped to 100 entries in `HomePersistenceManager`.
- **Phase 7 Audit Report & Readiness Checklist** (`docs/PHASE7_AUDIT_REPORT.md`, `docs/RELEASE_READINESS_CHECKLIST.md`).

---

## [0.6.0] - 2026-10-26 (Phase 6: Customizable Dashboard, Smart Search & Telemetry Export)

### Added
- **Customizable Dashboard**:
  - Drag-and-drop section reordering (Favorites, Rooms, Quick Actions, Energy, Activity).
  - Per-home persistent section visibility and layout preferences (`DashboardConfig`).
- **Device Search Engine** (`DeviceSearchEngine`):
  - In-memory multi-attribute filtering (name, room, connection status, device type).
  - Deterministic sorting by name, room hierarchy, and recent power usage.
- **Automation Builder 2.0**:
  - Enhanced rule configuration with interactive scene preview and trigger simulation.
- **Energy Insights Service & RFC-4180 CSV Export**:
  - Period-based energy consumption analytics (day, week, month) with device and room breakdowns.
  - RFC-4180 compliant CSV export with simulated estimate disclaimers.
- **Schema v6 Migration**:
  - Backward-compatible schema migration preserving user configurations.

---

## [0.5.0] - 2026-10-26 (Phase 5: Authoritative Command Pipeline, Loop Protection & Smart Home Health)

### Added
- **Authoritative Command Pipeline** (`CommandPipeline`):
  - Full command lifecycle tracking: queued -> pending -> confirmed / failed / timedOut / cancelled.
  - Request ID deduplication preventing redundant hardware execution.
  - Configurable simulated latency, packet loss, and exponential backoff retries.
  - Command cancellation support and bounded execution history.
- **Loop-Protected Automation Engine** (`AutomationEngine`):
  - Protection against infinite recursion (max recursion depth 3).
  - High-frequency trigger throttle (> 5 executions per second suppression).
  - Sensor threshold hysteresis hold preventing oscillatory flapping.
  - Rule execution explanation logging.
- **Smart Home Health Aggregator** (`HealthAggregator`):
  - Telemetry aggregation: online/offline/degraded device counts, battery levels, Wi-Fi RSSI.
  - Overall home health scoring (0-100) with diagnostic warnings.
- **Consumer Onboarding Experience**:
  - Device pairing flow with real-time status, retry, and cancellation handlers.
- **Demo Lab Chaos Sheet**:
  - Packet loss injection, forced device disconnects, and simulated reconnect storms.
- **Schema v5 Persistence Migration**.

---

## [0.4.0] - 2026-10-25 (Phase 4: Localization, Accessibility & Platform Hardening)

### Added
- **Internationalization (i18n)**:
  - English (`en`) and Vietnamese (`vi`) language support.
  - Reactive language switcher in Settings without app reload.
- **Accessibility Enhancements**:
  - Dynamic font scaling support (0.8x to 1.5x) without UI clipping.
  - Semantic descriptions for all custom interactive widgets.
- **Simulation Lifecycle Observer** (`SimulationLifecycleObserver`):
  - Suspends virtual clock timer when app transitions to background to conserve resources.
  - Re-synchronizes elapsed virtual time seamlessly upon foreground resumption.
  - Prevents redundant timer start attempts.
- **Platform Packaging Documentation**:
  - Android release configuration (`docs/ANDROID_RELEASE_GUIDE.md`).
  - iOS release checklist (`docs/IOS_RELEASE_CHECKLIST.md`).

---

## [0.3.0] - 2026-10-25 (Phase 3: Multi-Home Management, Energy Analytics & Editable Scenes)

### Added
- **Multi-Home Management**:
  - Dynamic home switcher (e.g. Primary Residence, Beach House).
  - Cascade deletion for rooms and homes with device re-assignment options.
- **Energy Analytics Engine** (`EnergyAnalyticsService`):
  - Real-time power telemetry and kWh calculations.
  - Tariff rate configuration ($/kWh) and cost estimation.
  - 30-day realistic historical energy sample seeding.
- **Editable Scenes**:
  - Custom scene creator and editor with multi-device action presets.
- **Favorites Reordering**:
  - Custom dashboard ordering for priority devices.
- **Schema v3 Persistence Migration**.

---

## [0.2.0] - 2026-10-24 (Phase 2: Simulation Engine, Virtual Clock & Automation Engine)

### Added
- **Deterministic Virtual Smart Home Engine** (`SimulationEngine`):
  - Device simulators for Bulbs, Fans, ACs, Sockets, Curtains, Smart Locks, and Multi-Sensors.
  - Realistic diurnal temperature and humidity environmental curves.
  - Thermal coupling between air conditioners and ambient room sensors.
- **Virtual Clock** (`VirtualClock`):
  - Controllable virtual time progression with acceleration factors (1x, 10x, 60x, 300x).
  - Manual step advancement for instant unit and integration testing.
- **Rule-Based Automation Engine**:
  - Time-of-day schedules and sensor threshold triggers.
- **Local JSON Storage Adapter** (`StorageAdapter`):
  - In-memory stub and web localStorage persistence abstraction.

---

## [0.1.0] - 2026-10-24 (Phase 1: IoT Connectivity & Device Provisioning)

### Added
- **Mock BLE Discovery Service**:
  - Simulated Bluetooth Low Energy peripheral scanning and RSSI signal tracking.
- **MQTT Transport Abstraction**:
  - Topic subscription and telemetry publication simulation.
- **Device Provisioning Wizard**:
  - Multi-step pairing flow: Scanning -> Pairing -> Wi-Fi Handshake -> Completed.
- **Core Domain Models**:
  - `SmartDevice`, `DeviceType`, `DeviceConnection`, `DeviceCommand`.

---

## [0.0.1] - 2026-10-23 (Phase 0: Project Genesis & Architecture Baseline)

### Added
- Initial project layout and structure.
- State management foundation using Flutter Riverpod.
- Clean architecture domain separation: `core/models`, `services`, `features`.
- Material 3 theme baseline with dark mode support.
- Initial widget smoke tests and analysis configurations.
