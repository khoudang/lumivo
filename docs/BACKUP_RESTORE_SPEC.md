# Lumivo — Backup & Restore Specification (V1 through V6)

**Specification Version:** 6.0 (Phase 8 Release)  
**Status:** Approved for Production  
**Supported Payload Format:** JSON UTF-8  

---

## 1. Backup Archive Schema Specification

Every exported backup is a JSON object containing a `metadata` header and collections of smart home entities.

```json
{
  "metadata": {
    "schemaVersion": 6,
    "exportedAt": "2026-10-27T00:00:00.000Z",
    "lumivoVersion": "0.6.0",
    "homeCount": 2,
    "deviceCount": 9
  },
  "homes": [ ... ],
  "rooms": [ ... ],
  "devices": [ ... ],
  "scenes": [ ... ],
  "automations": [ ... ],
  "activityEvents": [ ... ]
}
```

### 1.1 Validation Constraints & Boundaries
- **Maximum Archive Size:** 5,242,880 bytes (5 MB).
- **Maximum Nesting Depth:** 10 levels.
- **Maximum Device Limit:** 500 items.
- **Maximum Room Limit:** 100 items.
- **Maximum Scene Limit:** 200 items.
- **Maximum Automation Limit:** 200 items.
- **Maximum Event Log Limit:** 500 items.
- **Maximum String Length:** 128 characters per string field.

---

## 2. Backward Compatibility & Migration Matrix

The restoration engine (`BackupRestoreService`) dynamically migrates legacy backup formats into Schema Version 6:

| Schema Version | Introduced In | Legacy Format Differences | Migration Rules Applied |
| :--- | :--- | :--- | :--- |
| **V1** | Phase 1 | Flat device list without `homeId`, missing scenes and automations | Assign default `homeId = 'home-default'`, synthesize default rooms, set default scenes |
| **V2** | Phase 2 | Added rooms and simulated sensor properties | Map legacy device types, ensure default threshold rules |
| **V3** | Phase 3 | Added ambiance scenes and color temperatures | Reconcile scene device actions with existing device registry |
| **V4** | Phase 4 | Added mobile preferences and multi-locale tokens | Migrate user preferences into separate settings store |
| **V5** | Phase 5 | Added health scores and fault injection configs | Strip transient fault configs; preserve device telemetry |
| **V6** | Phase 6–8 | Current standard with referential integrity and sanitized secrets | Direct validation and atomic application |

---

## 3. Transactional Restoration Pipeline (9 Steps)

1. **Step 1 — Concurrency Lock:** Verifies that no other restore transaction is in progress (`_isRestoring` mutex flag).
2. **Step 2 — Pre-restore Snapshot:** Takes a complete snapshot of current state and stores it in recovery storage (`saveSnapshotBackup`).
3. **Step 3 — Parse JSON:** Deserializes raw UTF-8 JSON with strict error catching.
4. **Step 4 — Schema Validation:** Evaluates bounds, structure, types, and supported version (1–6).
5. **Step 5 — Normalization & Migration:** Upgrades legacy schemas (V1–V5) to Schema V6 standard format.
6. **Step 6 — Referential Verification:** Verifies room-to-home, device-to-room, scene-to-device, and automation-to-device links. Strips dangling references.
7. **Step 7 — Build Candidate State:** Constructs a candidate `HomeState` model in memory.
8. **Step 8 — Apply Transaction:** Persists candidate state to storage within a try/catch block.
9. **Step 9 — Commit or Rollback:**
   - **On Success:** Emits success notification, clears temporary caches, and updates UI providers.
   - **On Failure:** Automatically catches exceptions, restores previous snapshot from Step 2, and displays actionable error details.
