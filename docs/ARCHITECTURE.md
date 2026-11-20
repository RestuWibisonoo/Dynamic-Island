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
                                   |    IslandPanel    |                 |   IslandHosting   |
                                   | (Fixed 520x260 pt,|                 |       View        |
                                   |  Layer 33, NSPanel|                 |         |         |
                                   |  non-activating)  |                 |   IslandRootView  |
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
- **`IslandPanel`**: Subclass of `NSPanel` with `.nonactivatingPanel`, `canBecomeKey = true`, `becomesKeyOnlyIfNeeded = false`, `acceptsMouseMovedEvents = true`, and `.statusBar + 8` (Layer 33) window level. Uses a Fixed-Size Frame ($520 \times 260$ pt) anchored permanently to the screen top bezel. Ensures Dynamic Island stays anchored without physical window resize jumping.
- **`IslandHostingView`**: Custom `NSHostingView` subclass that overrides `hitTest(_:)` and configures an `NSTrackingArea` spanning the full $520 \times 260$ pt frame. Transparent regions outside the active island return `nil`, allowing clicks to pass through.
- **`IslandWindowController`**: Authoritative owner of window mouse routing and watchdog lifecycle. Features:
  - **Active Mouse-Position Watchdog**: A ~50 Hz timer running on `RunLoop.main` in `.common` mode that polls `NSEvent.mouseLocation` against dynamic `visibleIslandRect`.
  - **Authoritative Interactivity (`setPanelInteractive`)**: The instant the pointer exits `visibleIslandRect`, immediately sets `panel.ignoresMouseEvents = true` and stops the watchdog, unblocking underlying fullscreen applications (Chrome/Safari) with zero delay.
  - **Drag Protection**: Tracks `.leftMouseDown`, `.leftMouseDragged`, and `.leftMouseUp` to preserve slider scrubbing (volume/seek) until mouse-up.
  - **Fixed Frame Invariance**: NSPanel is never resized during expand/collapse; only SwiftUI content expands downward.

### Core / State
- **`IslandViewModel`**: Unified interaction state machine managing debounce timers, lock state, and provider data bindings.

### Core / Providers
- **`MediaProviding`**: Abstract protocol for media players (`currentTrack`, `isPlaying`, `progress`, `next`, `previous`, `toggle`).
- **`BatteryProviding`**: Protocol for battery percentage and charging state.
- **`SystemMonitorProviding`**: Protocol for CPU and RAM utilization.
- *Mock Implementations*: Clearly identified with `.sourceType = .mock` for testability and UI prototyping.

### UI & Presentation
- **`IslandSilhouette` & `FlushNotchShape`**: Custom geometry engine generating an outward continuous cubic Bézier curve:
  - Top horizontal segment exactly matches physical `notchWidth` flush against the screen bezel.
  - Outward-flaring cubic curves descend through `shoulderDepth: 18pt` with horizontal tangent at the notch bezel ($dy/dx = 0$) and vertical tangent at the outer side walls ($dx/dy = 0$).
  - Bottom corners retain $26$pt continuous card rounding.
- **`ExpandedIslandOutlineShape`**: Specular outline sharing the exact same curves, keeping the central top segment open across the physical notch.
- **`DeterministicEqualizerView`**: Keyframed, sinusoidal animation eliminating non-deterministic `CGFloat.random` calls during rendering.
- **`DesignTokens`**: Centralized tokens for spacing, corner radii, shoulder depth, and animation curves.
- **`ThemeManager`**: Supports OLED Pure Black, Frosted Glass, and macOS System appearance.
