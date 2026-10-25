# Lumivo Smart Home — Known Issues & Limitations

**Release:** Phase 7 Final (`phase-7-final`)  
**Target:** Flutter Web (Edge / Chrome)  
**Mode:** 100% Offline Simulation Mode  

---

## 1. Simulation Mode Boundaries & Constraints
- **Hardware Integration:** The application is architected and tested specifically for deterministic offline simulation. Real ESP32, physical Bluetooth Low Energy (BLE) peripheral scanning, hardware Wi-Fi provisioning, and real MQTT broker sockets are intentionally stubbed out via `MockBleService`, `MockProvisioningService`, and `MockMqttService`.
- **Clock Drift in Background Web Tabs:** When the browser tab running Lumivo Web is minimized or placed in background for extended periods, browser timer throttling (e.g., `requestAnimationFrame` and `Timer.periodic` throttling to once per minute) will pause virtual time progression until the tab is refocused.
- **Wasm Compilation Warning:** When compiling with `flutter build web --release`, Flutter outputs a dry-run advisory recommending the `--wasm` flag. The standard HTML/CanvasKit renderer pipeline is used by default for maximum compatibility across web browser engines.

## 2. Platform & Storage Characteristics
- **Web LocalStorage Limits:** On Web platforms, persistence is backed by browser `LocalStorage`. While typical Lumivo state occupies under 200KB, users operating in Private/Incognito browsing mode may encounter storage quota eviction upon closing the browser session.
- **Exporting Large CSV/JSON on Mobile Browsers:** Generating very large CSV or backup JSON downloads on mobile browsers may require enabling pop-ups or download permissions depending on browser security settings.

## 3. Residual Edge-Cases & Future Recommendations
- **Concurrent Multi-Tab Modification:** If the app is opened simultaneously in two separate browser tabs, changes made in Tab A do not dynamically broadcast via BroadcastChannel to Tab B until Tab B performs a state reload or page refresh.
- **Tariff Granularity:** Energy cost calculations utilize a single blended rate per kWh (default: 2,000 VND / $0.15 USD). Tiered time-of-use (TOU) tariffs are not yet supported in Phase 7 and are recommended for Phase 8.
