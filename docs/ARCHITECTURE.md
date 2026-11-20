# Architecture Documentation — Dynamic Island for macOS

## 1. System Overview

Dynamic Island for macOS is a lightweight, native AppKit and SwiftUI utility that integrates seamlessly with the MacBook camera notch and floating displays. The architecture adheres to strict separation of concerns, deterministic rendering, and robust multi-screen geometry calculation.

```
+-----------------------------------------------------------------------------------+
|                                  NSApplication                                    |
|                                       |                                           |
|                                  AppDelegate                                      |
+-----------------------------------------------------------------------------------+
           |                                                   |
           v                                                   v
+-----------------------+                             +--------------------+
|  NSStatusBar (Item)   |                             | IslandWindowController
+-----------------------+                             +--------------------+
                                                                |
                                             +------------------+------------------+
                                             |                                     |
                                             v                                     v
                                   +-------------------+                 +-------------------+
                                   |    IslandPanel    |                 |   NSHostingView   |
                                   |   (NSPanel, non-  |                 |         |         |
                                   |    activating)    |                 |   IslandRootView  |
                                   +-------------------+                 +-------------------+
                                                                                   |
                                                               +-------------------+-------------------+
                                                               |                                       |
                                                               v                                       v
                                                    +--------------------+                  +--------------------+
                                                    |  CompactIslandView |                  | ExpandedIslandView |
                                                    +--------------------+                  +--------------------+
                                                               |                                       |
                                                               +-------------------+-------------------+
                                                                                   |
                                                                                   v
                                                                        +---------------------+
                                                                        |   IslandViewModel   |
                                                                        |   (State Machine)   |
                                                                        +---------------------+
                                                                           /        |        \
                                            +-----------------------------+         |         +-----------------------------+
                                            v                                       v                                       v
                                 +--------------------+                  +--------------------+                  +--------------------+
                                 |  MediaProviding    |                  |  BatteryProviding  |                  | SystemMonitorProv. |
                                 | (Mock/Real Spotify)|                  | (Mock/IOPowerSrcs) |                  | (Mock/Mach kernel) |
                                 +--------------------+                  +--------------------+                  +--------------------+
```

---

## 2. Component Responsibilities

### Core / Models
- **`IslandDisplayState`**: Defines explicit presentation states (`.compact`, `.expanded(reason: .hover | .locked)`, `.temporaryHUD`).
- **`DisplayContext`**: Encapsulates screen candidates and defines the target selection strategy.
- **`IslandLayoutMetrics`**: Single Source of Truth for geometry. Computes frames for compact, expanded, notch clearance, and handles multi-monitor negative screen coordinates.

### Core / Display
- **`ScreenDetector`**: Observes `NSApplication.didChangeScreenParametersNotification` and publishes updated `IslandLayoutMetrics`. Prioritizes the built-in notch display before falling back to external displays.

### Core / Window
- **`IslandPanel`**: Subclass of `NSPanel` with `.nonactivatingPanel`, `canBecomeKey = false`, `becomesKeyOnlyIfNeeded = false`, `acceptsMouseMovedEvents = false`, and `.statusBar + 1` window level. Ensures full-screen video players (e.g. YouTube in Chrome/Safari) never lose key focus.
- **`IslandHostingView`**: Custom `NSHostingView` subclass that overrides `hitTest(_:)`. Bounds checks against the dynamic active island geometry; transparent areas outside the island return `nil`, passing clicks, mouse moves, and hover gestures through to underlying fullscreen apps.
- **`IslandWindowController`**: Authoritative owner of hover detection and window geometry. Replaces fragile SwiftUI hover tracking with global/local `mouseMoved` monitors and geometric hysteresis (`hoverDetectionRect`), preventing hover jitter feedback loops during window resizing. Manages the physical size and position of the `IslandPanel`. Immediately enlarges the panel on expansion, and shrinks it back to compact size after the collapse animation finishes (350ms).

### Core / State
- **`IslandViewModel`**: Unified interaction state machine managing debounce timers, lock state, and provider data bindings.

### Core / Providers
- **`MediaProviding`**: Abstract protocol for media players (`currentTrack`, `isPlaying`, `progress`, `next`, `previous`, `toggle`).
- **`BatteryProviding`**: Protocol for battery percentage and charging state.
- **`SystemMonitorProviding`**: Protocol for CPU and RAM utilization.
- *Mock Implementations*: Clearly identified with `.sourceType = .mock` for testability and UI prototyping.

### UI & Presentation
- **`FlushNotchShape`**: Custom geometry-resilient shape that hugs the top bezel with zero gap in compact mode.
- **`DeterministicEqualizerView`**: Keyframed, sinusoidal animation eliminating non-deterministic `CGFloat.random` calls during rendering.
- **`DesignTokens`**: Centralized tokens for spacing, corner radii, and animation curves.
- **`ThemeManager`**: Supports OLED Pure Black, Frosted Glass, and macOS System appearance.
