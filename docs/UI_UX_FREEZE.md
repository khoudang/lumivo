# Phase 9: Release Candidate UI/UX & Localization Freeze Specification

## 1. Executive Summary & Freeze Declaration

As part of Phase 9 (Release Candidate & UX Freeze) for Lumivo AIoT Command Center, this document formalizes the complete visual, architectural, and localization freeze across the application. 

- **Status**: FROZEN (Release Candidate 1.0.0)
- **Design Philosophy**: Dark Minimal AIoT System
- **Key Tenet**: 100% Offline Simulation, Zero Cloud Leakage, Industrial Reliability
- **Accessibility Standard**: WCAG 2.1 AA Conformance (touch targets $\ge 48\times 48\,\text{pt}$, dynamic text scaling to $2.0\times$, reduced motion)
- **Localization Parity**: 100% key-for-key correspondence across English (`en`) and Vietnamese (`vi`) (311 standardized keys)

---

## 2. Design Token System: Dark Minimal Architecture

All interface components are governed by centralized design tokens defined in `lib/core/theme/app_theme.dart`. Ad-hoc styling, hardcoded magic dimensions, and arbitrary color literals are prohibited.

### 2.1 Color Tokens (`AppColors`)
The color palette emphasizes high contrast against deep slate backgrounds (`#0B0E14` / `#121824`) for optimal OLED power efficiency and low eye strain in industrial and ambient environments.

| Token | Hex Value | Semantic Role |
| :--- | :--- | :--- |
| `primary` | `#0A84FF` | Primary actions, focused state rings, active accents |
| `primaryLight` | `#3395FF` | Hover states, elevated primary surfaces |
| `secondary` | `#03DAC6` | Telemetry highlights, eco indicators |
| `background` | `#0B0E14` | Deep foundation background |
| `surface` | `#121824` | Surface panels, sheets, dialog bodies |
| `surfaceElevated` | `#1A2234` | Cards, elevated interactive tiles |
| `surfaceBorder` | `#222E44` | Structural divider lines and borders (1px) |
| `surfaceBorderStrong` | `#334155` | Focused borders, active stroke dividers |
| `textPrimary` | `#EAEFF8` | High-emphasis body, headers, active metrics |
| `textSecondary` | `#94A3B8` | Subtitles, labels, secondary metadata |
| `muted` | `#64748B` | Disabled copy, placeholders |
| `mutedDark` | `#334155` | Inactive tracks, empty slot outlines |
| `danger` / `error` | `#EF4444` | Destructive buttons, alert badges |
| `warning` | `#F59E0B` | Warning banners, unconfirmed states |
| `green` / `success` | `#10B981` | Online indicators, active device switches |

### 2.2 Spatial Tokens (`AppSpacing`)
Spacing follows a strict 4pt / 8pt rhythmic grid:
- `AppSpacing.xs`: `4.0` — Icon-to-text spacing, compact badge padding
- `AppSpacing.sm`: `8.0` — Tile internal padding, item separation in tight rows
- `AppSpacing.md`: `16.0` — Standard container padding, form field vertical separation
- `AppSpacing.lg`: `24.0` — Section separation, sheet edge gutters
- `AppSpacing.xl`: `32.0` — Modal edge separation, major hero block spacing

### 2.3 Radii Tokens (`AppRadii`)
Border curvatures maintain consistent chamfering:
- `AppRadii.sm`: `BorderRadius.circular(8)` — Chips, badges, small pills
- `AppRadii.md`: `BorderRadius.circular(12)` — Standard inputs, buttons
- `AppRadii.lg`: `BorderRadius.circular(16)` — Cards, interactive grid elements
- `AppRadii.card`: `BorderRadius.circular(16)` — Metric cards, telemetry charts
- `AppRadii.dialog`: `BorderRadius.circular(20)` — Confirmation dialogs
- `AppRadii.sheet`: `BorderRadius.vertical(top: Radius.circular(24))` — Bottom sheets

### 2.4 Touch Target Minimums (`AppTouchTargets`)
- `AppTouchTargets.min`: `48.0` pt (WCAG 2.1 Criterion 2.5.5 / Target Size Level AA 2.5.8).
- Globally enforced via ThemeData button themes (`ElevatedButtonThemeData`, `OutlinedButtonThemeData`, `TextButtonThemeData`, `IconButtonThemeData`) with `minimumSize: const Size(0, AppTouchTargets.min)` and `minWidth`/`minHeight` constraints on standalone `IconButton` and `InkWell` containers.

---

## 3. UI Component Consistency Rules

1. **Buttons & Heights**:
   - Primary action buttons: min-height 48pt, radius 12pt, background `AppColors.primary`, foreground `AppColors.textPrimary`.
   - Secondary / Destructive actions: min-height 48pt, radius 12pt, styled with clear semantic cues (e.g., `AppColors.danger`).
2. **Dialog Presentations**:
   - Always render with rounded corners (`Radius.circular(20)`), `AppColors.surface` background, and border `AppColors.surfaceBorder`.
   - Header contains title with semantic icon; actions aligned at bottom trailing edge (`Cancel` preceding confirmative/destructive button).
3. **Status Badges & Chips**:
   - Online / Active: `AppColors.green` dot with 12% alpha background.
   - Offline / Inactive: `AppColors.mutedDark` dot.
   - Fault / Warning: `AppColors.danger` or `AppColors.warning`.
4. **Bottom Sheets**:
   - `DraggableScrollableSheet` or modal sheets feature a 44x4pt drag handle at top center, `Radius.vertical(top: Radius.circular(24))` radius, and `isScrollControlled: true` to prevent keyboard / small viewport clipping.
5. **Loading & Empty States**:
   - Standardized `CircularProgressIndicator` with `strokeWidth: 2.5` colored with `AppColors.primary`.
   - Empty states provide dedicated icons, localized description, and a clear call-to-action button where applicable.

---

## 4. Full-Screen UX Audit Matrix (320x600 Viewport Conformance)

All 20 screens and modal bottom sheets have been audited on an ultra-compact viewport ($320 \times 600\,\text{pt}$, iPhone SE 1st gen / compact embedded displays). Every screen renders without `RenderFlex` overflow exceptions, includes proper back navigation, and cleanly presents empty and error states.

| # | Screen / Sheet | Route / Component | 320x600 Viewport | Back Navigation | Empty / Error Handling |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **Splash Screen** | `SplashScreen` | PASS (Zero overflow) | Auto-progress | Graceful fallback if init errors occur |
| 2 | **Onboarding / Welcome** | `OnboardingScreen` | PASS (Zero overflow) | Step dots & Skip | PageView wrap with scroll fallback |
| 3 | **Dashboard** | `DashboardScreen` | PASS (Zero overflow) | Root / Nav drawer | Localized empty room / device widgets |
| 4 | **Multi-Home Selector** | `HomeSelectorSheet` | PASS (Zero overflow) | Dismiss handle | Add home validation, active home chip |
| 5 | **Rooms Screen** | `RoomsScreen` | PASS (Zero overflow) | App bar back | `rooms_empty_state_text` when empty |
| 6 | **Device Search** | `DeviceSearchScreen` | PASS (Zero overflow) | App bar back | Filter zero-state with reset filter CTA |
| 7 | **Device Detail** | `DeviceDetailScreen` | PASS (Zero overflow) | App bar back | Real-time telemetry connection warning |
| 8 | **Device Settings Sheet** | `DeviceSettingsSheet` | PASS (Zero overflow) | Dismiss handle | Name validation, destructive confirmation |
| 9 | **Add Device Sheet** | `AddDeviceSheet` | PASS (Zero overflow) | Dismiss handle | Discovery timeout with actionable retry |
| 10 | **Scenes Tab** | `ScenesTab` (Automation) | PASS (Zero overflow) | Tab switch | Empty scenes illustration & CTA |
| 11 | **Scene Editor Sheet** | `SceneEditorSheet` | PASS (Zero overflow) | Dismiss handle | Validation for empty name & zero actions |
| 12 | **Automation Rules** | `AutomationScreen` | PASS (Zero overflow) | Tab switch | Empty automation state & wizard trigger |
| 13 | **Create Automation** | `CreateAutomationScreen` | PASS (Zero overflow) | App bar back | Step validation, trigger/condition summary |
| 14 | **Automation Builder** | `AutomationBuilderWizard` | PASS (Zero overflow) | Cancel / Prev | Actionable chip pickers, type safety |
| 15 | **Activity History** | `ActivityScreen` | PASS (Zero overflow) | App bar back | Clear history with confirmation modal |
| 16 | **Notification Center** | `NotificationsSheet` | PASS (Zero overflow) | Dismiss handle | Empty notification state, clear all modal |
| 17 | **Device Health** | `HealthScreen` | PASS (Zero overflow) | App bar back | Filter by health status, empty warning |
| 18 | **Energy Analytics** | `EnergyScreen` | PASS (Zero overflow) | App bar back | Tariff config modal, manual sync feedback |
| 19 | **Demo Lab** | `DemoLabScreen` | PASS (Zero overflow) | App bar back | Virtual clock fast-forward, device toggle |
| 20 | **Backup & Restore** | `BackupRestoreScreen` | PASS (Zero overflow) | App bar back | JSON schema error alerts, secret sanitizer |
| 21 | **Privacy Center** | `PrivacyCenterScreen` | PASS (Zero overflow) | App bar back | Offline assurance tile, demo reset modal |
| 22 | **Recovery Center** | `RecoveryCenterScreen` | PASS (Zero overflow) | App bar back | Destructive factory reset 2-step modal |
| 23 | **Settings Screen** | `SettingsScreen` | PASS (Zero overflow) | App bar back | Preferences toggle, reset layout modal |
| 24 | **User Profile** | `ProfileScreen` | PASS (Zero overflow) | App bar back | Bilingual switcher, tariff edit modal |

---

## 5. Localization Freeze (100% Key Parity in EN & VI)

### 5.1 Architecture
Localization is driven by `lib/core/localization/`:
- `strings_en.dart`: Master English string registry (311 keys)
- `strings_vi.dart`: Master Vietnamese string registry (311 keys)
- `app_localizations.dart`: Type-safe getters and parameterized helper methods with automatic fallbacks
- `localization_provider.dart`: Reactive Riverpod provider tied to `userProfileProvider.language`

### 5.2 Key Parity & Completeness
- Total standardized keys: **311**
- Missing keys in English: **0**
- Missing keys in Vietnamese: **0**
- Hardcoded English strings in presentation layer: **0**

### 5.3 Dynamic String Parameter Interpolation
Parameterized strings utilize template bracket notation (e.g. `Room "{name}" added`) and are accessed via typed methods:
```dart
l10n.roomAdded(name)           // EN: 'Room "Kitchen" added' | VI: 'Đã thêm phòng "Kitchen"'
l10n.roomDeleted(name)         // EN: 'Room "Kitchen" deleted' | VI: 'Đã xóa phòng "Kitchen"'
l10n.confirmDeleteRoomBody(name)
l10n.sceneExecuted(name)       // EN: 'Scene "Evening" executed successfully!' | VI: 'Kịch bản "Evening" đã thực thi thành công!'
l10n.ruleCreated(name)         // EN: 'Rule "Night Mode" created successfully!' | VI: 'Quy tắc "Night Mode" đã được tạo thành công!'
```

---

## 6. Accessibility & Conformance (WCAG 2.1 AA)

1. **Touch Target Size**:
   - Every tappable control (buttons, icon buttons, list items, slider thumbs, segment pills) meets or exceeds $48 \times 48\,\text{pt}$.
2. **Text Scaling Compliance**:
   - Evaluated under `TextScaler.linear(1.5)` and `TextScaler.linear(2.0)`.
   - All labels use `TextOverflow.ellipsis`, `FittedBox.scaleDown`, or expand inside scrollable viewports, preventing clipping and visual distortion.
3. **Reduced Motion Support**:
   - Evaluated with `MediaQueryData.disableAnimations = true`.
   - Radar scanning pulses in `AddDeviceSheet` and telemetry animations suppress looping animations when reduced motion is preferred by the operating system.
4. **Semantics & Screen Readers**:
   - Interactive icons provide explicit `tooltip` attributes and `Semantics(label: ...)` tags for assistive technologies.
   - Screen headers and modal titles declare explicit semantic headings.

---

## 7. Verification & Test Evidence

All acceptance criteria are continuously validated by widget and unit tests:
- `test/widget/phase9_ui_freeze_test.dart`: Complete Phase 9 UI/UX Freeze regression test suite
- `test/widget/phase7_ui_accessibility_audit_test.dart`: Accessibility, touch targets, and destructive confirmations
- `test/widget/phase8_privacy_experience_test.dart`: Privacy Center, Recovery Center, and Backup/Restore workflows
- Static Analysis: `flutter analyze` reports **0 errors, 0 warnings, 0 lints**.
