# 🏝️ Dynamic Island for macOS

A native macOS Dynamic Island utility built with **Swift 6, SwiftUI, and AppKit**. Designed to integrate seamlessly with the MacBook camera notch and external displays with a true Apple-native feel (*first-party experience*).

---

## 🏗️ Architecture Overview

The codebase is organized into a modular, testable architecture:

* **`DynamicIslandCore`**: Shared library target containing:
  * **`Core/Models`**: `IslandDisplayState`, `IslandLayoutMetrics` (single source of truth for geometry), `DisplayContext`.
  * **`Core/Display`**: `ScreenDetector` with multi-monitor support and display prioritization.
  * **`Core/Window`**: `IslandPanel` (non-activating, non-key, zero focus stealing) and `IslandWindowController` (dynamic frame synchronization).
  * **`Core/State`**: `IslandViewModel` with formalized state transitions.
  * **`Core/Providers`**: `MediaProviding`, `BatteryProviding`, `SystemMonitorProviding` (clean abstraction for real vs mock providers).
  * **`Core/Services`**: `LaunchAtLoginManager` (using Apple's `SMAppService`) and `AppLogger` (OSLog).
  * **`UI/Theme`**: `ThemeManager` (OLED Pure Black, Frosted Glass, System Appearance) and `DesignTokens`.
  * **`UI/Views`**: `FlushNotchShape`, `CompactIslandView`, `ExpandedIslandView`, `IslandRootView`.
* **`DynamicIsland`**: Thin executable entry point invoking `@main` AppKit lifecycle.
* **`Tests`**: Automated unit test suite verifying geometry, state transitions, and providers.

---

## ✨ Features & Status

### Working Features
- 📐 **Pixel-Perfect Notch Integration**:
  - Automatically detects MacBook notch width and height using `auxiliaryTopLeftArea` and `safeAreaInsets`.
  - Seamlessly transforms into a **Floating Dynamic Pill** on external monitors and non-notch Macs.
- 🪟 **Focus-Safe Window Architecture**:
  - `NSPanel` configured with `canBecomeKey = false` and `.nonactivatingPanel`.
  - **Does not break fullscreen video playback**: YouTube, Netflix, and browser video navigation bars auto-hide normally without getting stuck.
- 📏 **Dynamic Window Sizing**:
  - In compact state, the window is physically shrunk to 32pt high so the screen below is 100% free of overlays.
- 🎨 **Adaptive Themes & Apple Aesthetic**:
  - Supports OLED Pure Black, Frosted Glass (Vibrant), and macOS System appearance.
  - Zero shadow and zero border in compact mode for a 100% seamless hardware blend.
  - Specular rim highlight in expanded mode.
- 🔒 **Pin / Lock & Escape Support**:
  - Click the compact island to open and pin it.
  - Dedicated "Kunci" toggle and Close (`✕`) button.
  - Global `Esc` key listener closes the expanded card immediately.
- 🚀 **Launch at Login**:
  - Built on Apple's `SMAppService` with an in-place menu bar toggle.
- 🧪 **Deterministic Animations**:
  - Live equalizer bars use deterministic phase-driven curves without random values inside SwiftUI body rendering.

### Mock Features (Development Stage)
- 🎵 **Media Player**: Currently powered by `MockMediaProvider`. Cycles through a demo playlist (Starboy, Blinding Lights, Save Your Tears), tracks simulated playback progress, and supports interactive play/pause, seek, next, and previous buttons.
- 🔋 **Battery Indicator**: Powered by `MockBatteryProvider` (92%, Charging).
- 📊 **System Monitor**: Powered by `MockSystemMonitorProvider` (CPU & RAM usage).
- 📦 **Drop Shelf**: Visual drag-and-drop shelf container (file stash integration deferred to Phase 3).

---

## 🛠️ Build, Test & Run

### 1. Run in Development Mode
```bash
make run
# or
swift run DynamicIsland
```

### 2. Run the Unit Test Suite
```bash
make test
# or
swift run TestRunner
```

### 3. Build the macOS App Bundle (`DynamicIsland.app`)
```bash
make bundle
```
The resulting `DynamicIsland.app` will be created in the project root with the bundle identifier `com.restuwibisono.DynamicIsland`.

---

## 🗺️ Roadmap & Next Steps
- [x] **Phase 1**: Architecture Stabilization, Display Selection, Dynamic Window Sizing, Non-key focus fix, Deterministic animations, and Unit Testing.
- [ ] **Phase 2**: Real-time Media Provider (AppleScript & ScriptingBridge for Spotify and Apple Music).
- [ ] **Phase 3**: Real System Providers (IOPowerSources for Battery, Host Statistics for CPU/RAM).
- [ ] **Phase 4**: Interactive File Drop Shelf with live file preview thumbnails and AirDrop target.
- [ ] **Phase 5**: Preferences Window (UI settings, hover sensitivity adjustment, shortcuts).

---

## 📖 Technical Documentation
- [Architecture Details](docs/ARCHITECTURE.md)
- [Engineering Audit Report](docs/ENGINEERING_AUDIT.md)
- [Testing & Quality Assurance](docs/TESTING.md)
