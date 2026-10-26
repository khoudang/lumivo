# Lumivo — Data Privacy Model & Storage Architecture

**Document Version:** 1.0 (Phase 8 Release)  
**Security Classification:** Consumer Privacy Standard  
**Operating Environment:** 100% Offline Client Simulation (No Cloud Backend)  

---

## 1. Core Privacy Principles

1. **Complete Client-Side Confinement:** All application logic, state management, scheduling, automation execution, and data persistence reside exclusively on the user's client device (Web LocalStorage / IndexedDB / in-memory cache).
2. **Zero Telemetry & Exfiltration:** No analytics SDKs, trackers, third-party beacons, or external API pings exist in the codebase.
3. **Data Minimization:** No personally identifiable information (PII) is required to operate the application.
4. **Sanitized Serialization:** All user exports and persistence payloads are scrubbed of any user-entered credential tokens or simulated Wi-Fi passphrases.
5. **Atomic Data Erasure:** Full factory reset and per-category clearing mechanisms reliably delete stored records without orphaned remnants.

---

## 2. Local Storage Categories Breakdown

The application maintains 9 distinct local data categories:

| Category Key | Entity / Model | Storage Backing | Sensitivity Level | Sanitization Rule |
| :--- | :--- | :--- | :--- | :--- |
| `homes` | `Home` | LocalStorage JSON | Low | Stripped of metadata timestamps in compact views |
| `rooms` | `Room` | LocalStorage JSON | Low | Scoped to parent `homeId` |
| `devices` | `SmartDevice` | LocalStorage JSON | Medium | `customData` and configuration maps scrubbed of password/token keys |
| `scenes` | `Scene` | LocalStorage JSON | Low | Orphaned device action references pruned |
| `automations` | `AutomationRule` | LocalStorage JSON | Low | Sensor device references verified against device registry |
| `activityEvents` | `ActivityEvent` | LocalStorage JSON | Low | Capped at 500 events; older events pruned FIFO |
| `energySamples` | `EnergySample` | LocalStorage JSON | Low | Aggregated time-series samples |
| `userProfile` | `UserProfile` | LocalStorage JSON | Low | Avatar, display name, language; no passwords stored |
| `appPreferences` | Settings State | LocalStorage JSON | Low | Theme, locale, accessibility settings |

---

## 3. Threat Protections & Data Safeguards

### 3.1 Credential & Secret Scrubbing
The `SecretSanitizer` utility audits data structures before export or persistence:
- **Key Blacklist:** Keys matching `pass`, `pwd`, `secret`, `token`, `key`, `auth`, `cred`, `pin`, `private` are identified.
- **Redaction:** Values are replaced with string token `[REDACTED]`.
- **Deep Recursion:** Nested maps and lists are recursively inspected up to 10 levels deep.

### 3.2 CSV Export Protection
When users export activity logs or device inventories to CSV format, malicious formula injection is prevented:
- Any cell value beginning with `=`, `+`, `-`, `@`, `\t`, or `\r` is prepended with a single apostrophe (`'`).
- Internal quotes are escaped using standard RFC-4180 rules.

### 3.3 Storage Resilience & Quota Management
- Storage write operations catch `QuotaExceededError` and similar platform exceptions.
- The persistence layer maintains fallback emergency snapshot records and alerts the user cleanly through the Recovery Center instead of crashing or discarding existing data.
