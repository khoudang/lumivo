# Lumivo — Privacy & Store Disclosures Specification

**Document Version:** 1.0.0 (Phase 10 Release & Distribution)  
**Security & Privacy Tier:** Zero-Data Collection / 100% Offline Client  
**Applicability:** Apple App Store (App Privacy Nutrition Label) & Google Play Console (Data Safety Form)  
**Application Title:** Lumivo — Smart Home Simulator  
**Bundle ID / Package Name:** `com.lumivo.smarthome`  

---

## 1. Executive Privacy Architecture Summary

Lumivo is engineered as an **offline-first, zero-telemetry application**. 
- **Zero External Network Exfiltration:** The app never initiates HTTP, HTTPS, WebSocket, or gRPC connections to any remote server or cloud infrastructure.
- **No Third-Party SDKs:** No analytics SDKs (Google Analytics, Firebase, Mixpanel, Segment), crash reporters (Sentry, Crashlytics), or advertising networks (AdMob, Unity Ads, AppLovin) are integrated.
- **Local Persistence Confinement:** All application state, user preferences, simulated devices, automation rules, and activity events are stored exclusively in on-device local storage (`SharedPreferences` on Android / `NSUserDefaults` on iOS / `localStorage` on Web).
- **Sanitized Backup Payload:** Exported JSON configurations undergo recursive credential and token scrubbing before serialization.
- **Immediate Data Erasure:** Full factory resets and selective category deletion clear local records instantaneously without remnants.

---

## 2. Apple App Store Privacy Nutrition Label (App Store Connect)

Under Apple App Store Review Guideline 5.1 and App Store Connect privacy requirements, all developers must disclose their data collection practices.

### 2.1 Core Question: Does this app collect data?
> **Answer: NO, DATA NOT COLLECTED**  
> *"Neither the developer nor any third-party partners collect any data from this app."*

### 2.2 Category-by-Category Audit Matrix

| Apple Data Category | Collected? | Linked to User? | Used for Tracking? | Justification / Technical Verification |
| :--- | :--- | :--- | :--- | :--- |
| **Contact Info** (Name, Email, Phone, Address) | **No** | N/A | No | Display name and email shown in `UserProfile` are stored solely in local `SharedPreferences`. No network transit. |
| **Health & Fitness** | **No** | N/A | No | No health or biometric metrics collected. |
| **Financial Info** (Payment Info, Credit Info) | **No** | N/A | No | Free app, no in-app purchases, no billing APIs. |
| **Location** (Precise / Coarse Location) | **No** | N/A | No | No GPS or cell tower permissions requested (`NSLocationWhenInUseUsageDescription` is omitted). |
| **Sensitive Info** (Racial, Political, Biometric) | **No** | N/A | No | No sensitive personal attributes gathered. |
| **Contacts** | **No** | N/A | No | Address book is never accessed (`CNContactStore` omitted). |
| **User Content** (Emails, Text messages, Photos, Audio) | **No** | N/A | No | Device files/photos are not accessed. JSON backups are explicitly user-driven file exports. |
| **Browsing History** | **No** | N/A | No | No embedded web browsers, web views, or link tracking. |
| **Search History** | **No** | N/A | No | Device Search filtering executes purely in-memory against local mock device list. |
| **Identifiers** (User ID, Device ID, IDFA) | **No** | N/A | No | No IDFA (`ASIdentifierManager` omitted). Mock device UUIDs are local simulation artifacts only. |
| **Purchases** | **No** | N/A | No | No storefront or transaction history. |
| **Usage Data** (Product Interaction, Advertising Data) | **No** | N/A | No | Zero telemetry. No button clicks, screen visits, or duration pings are emitted. |
| **Diagnostics** (Crash Logs, Performance Data) | **No** | N/A | No | No crash logging frameworks bundled. Diagnostic data stays in local application memory. |
| **Other Data Types** | **No** | N/A | No | No additional data collected. |

### 2.3 App Tracking Transparency (ATT) Conformance
- **Is ATT prompt required?** **NO**.
- Lumivo does not access `AppTrackingTransparency.framework`, does not read the `advertisingIdentifier` (IDFA), and does not track users across third-party websites or apps.

---

## 3. Google Play Data Safety Form Responses (Google Play Console)

Google Play requires accurate answers to the Data Safety questionnaire to ensure consumer protection and policy compliance.

### 3.1 Overview Questions

1. **Does your app collect or share any of the required user data types?**  
   👉 **NO**  
   *All smart home configurations and activity logs remain strictly on the user's physical device.*

2. **Is all of the user data collected by your app encrypted in transit?**  
   👉 **Not Applicable (N/A)**  
   *No data is transmitted over a network connection; Lumivo is 100% offline.*

3. **Do you provide a way for users to request that their data be deleted?**  
   👉 **YES**  
   *Users can delete all stored smart home data, logs, and preferences at any time via the in-app "Reset Demo Data" or "Factory Reset" buttons in Settings and Privacy Center.*

4. **Is your app targeted at children?**  
   👉 **NO**  
   *Targeted at general audiences (Designated age group: 13+ / Everyone).*

### 3.2 Runtime & Android Manifest Permissions Audit

Lumivo enforces the principle of least privilege. The Android configuration has zero invasive or dangerous permissions:

| Permission | Declared in Manifest? | Necessity |
| :--- | :--- | :--- |
| `android.permission.INTERNET` | **No** (Stripped from release manifest) | No network access permitted. |
| `android.permission.ACCESS_NETWORK_STATE` | **No** | No connectivity checks needed. |
| `android.permission.BLUETOOTH` / `BLUETOOTH_CONNECT` | **No** | BLE pairing is simulated internally; no real Bluetooth radio access requested. |
| `android.permission.ACCESS_FINE_LOCATION` | **No** | No geolocation required. |
| `android.permission.CAMERA` | **No** | No camera access requested. |
| `android.permission.RECORD_AUDIO` | **No** | No microphone access requested. |
| `android.permission.READ_EXTERNAL_STORAGE` | **No** | No broad storage permission needed. |

---

## 4. App Store Review Guidelines Conformance Analysis

### 4.1 Guideline 2.3 — Accurate Metadata
- **Requirement:** Apps must clearly describe their features and functionality. Apps that simulate hardware must not deceive users into believing they are purchasing a utility for physical IoT devices.
- **Conformance:**
  - App title explicitly includes the identifier: `Lumivo — Smart Home Simulator`.
  - App Subtitle states: `100% Offline Home Simulator`.
  - Welcome screen, Onboarding flow, Settings screen, Smart Home Health screen, and Privacy Center include explicit badges indicating **100% Offline Simulation Mode**.
  - Store listings in English and Vietnamese explicitly disclose upfront that no real hardware, BLE radios, or cloud bridges are required.

### 4.2 Guideline 4.0 — Design & Functional Quality
- **Requirement:** Apps should be complete, provide full functionality, and offer intuitive user interactions without dead ends or broken links.
- **Conformance:**
  - Zero broken buttons: all interactive tiles, switches, and sliders trigger verified state changes or feedback dialogs.
  - No dead ends: back navigation, cancel buttons, and dismiss sheets are consistently implemented with standard 48x48 pt touch targets.
  - Responsive layouts: tested on mobile viewports (320px to 430px) and tablet viewports (768px to 1024px) with zero `RenderFlex` overflow errors.

### 4.3 Guideline 5.1 — Legal & Privacy
- **Requirement:** Respect user privacy, secure stored data, and provide transparent privacy notices.
- **Conformance:**
  - Complete client confinement with zero tracking.
  - Dedicated in-app **Privacy & Data Center** providing storage breakdown and emergency recovery snapshots.
  - Hosted Privacy Policy ready for publication.

---

## 5. Official Privacy Policy Document (Ready for Web Hosting)

Below is the complete text of the Privacy Policy for public hosting at `https://lumivo.app/privacy` or GitHub Pages:

```markdown
# Privacy Policy for Lumivo — Smart Home Simulator

**Last Updated:** October 27, 2026  
**Effective Date:** October 27, 2026  

Thank you for choosing **Lumivo — Smart Home Simulator** ("Lumivo", "the App", "we", "us", or "our"). We are committed to protecting your personal privacy. This Privacy Policy explains our practices regarding data privacy, local storage, and the complete absence of data collection.

### 1. Summary: Zero Data Collection
Lumivo is designed as a **100% offline simulation application**. We do not collect, transmit, store, sell, or share any personal information, device identifiers, location metrics, or usage analytics.

### 2. Operating Architecture & 100% Offline Mode
- **No Remote Servers:** Lumivo does not connect to any external cloud API, remote database, or backend server.
- **No Third-Party SDKs:** The application does not contain advertising libraries, tracking beacons, social media plugins, or remote crash reporting SDKs.
- **Simulation Hardware:** All smart home devices (lights, fans, climate units, curtains, sensors, locks), energy consumption metrics, and network events are generated deterministically by on-device software state machines. No physical Bluetooth, Wi-Fi, or Zigbee hardware is accessed.

### 3. Local On-Device Data Storage
All data generated within Lumivo is stored strictly on your local device:
- **Stored Data Types:** Custom room definitions, simulated device names, automation rules, ambiance scenes, activity history logs, and UI preferences (theme mode, accent hue, temperature unit).
- **Storage Technology:** Stored locally via platform-standard persistence (`SharedPreferences` on Android, `NSUserDefaults` on iOS, or `localStorage` in browser environments).
- **Access Restrictions:** This data is sandboxed by your operating system and is never transmitted off your device.

### 4. Backup & Data Erasure
- **Exporting Backups:** When you export a smart home configuration backup, a sanitized JSON file is generated locally. All simulated credentials or sensitive keys are scrubbed automatically.
- **Data Erasure:** You have complete control over your data. You can delete activity logs, notification history, or perform a complete "Factory Reset to Demo Data" at any time via the in-app Settings or Privacy Center. Uninstalling the application completely deletes all locally stored data.

### 5. Children's Privacy
Because Lumivo does not collect any personal data whatsoever, the application does not knowingly collect or solicit personal information from children under the age of 13 (or under 16 in the European Union).

### 6. Changes to this Policy
If we update this Privacy Policy, the revised version will be published with an updated "Last Updated" date. Any updates will maintain our core commitment to zero external data collection.

### 7. Contact Us
If you have any questions or feedback regarding this Privacy Policy or Lumivo, please contact our team:
- **Email:** privacy@lumivo.app
- **Website:** https://lumivo.app
```
