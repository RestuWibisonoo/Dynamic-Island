# Testing & Quality Assurance Documentation

## 1. Overview
The testing architecture is built on deterministic unit tests verifying:
1. **Geometry & Multi-Screen Positioning**: Hardware notch math, non-notch floating pill math, fixed-size panel invariance, and negative origin coordinates.
2. **Outward Continuous Silhouette Curves**: Mathematical symmetry, hardware notch attachment width, $C^1$ smooth tangents, and open-top specular outline.
3. **Active Mouse-Position Watchdog**: ~50 Hz timer lifecycle, duplicate timer prevention, instant click-through on exit, transparent strip pass-through, and drag interaction safety.
4. **State Machine Invariants**: Initial compact state, hover expansion, lock-open enforcement, debounce, and hover-exit cancellation.
5. **Data Provider Contracts**: Track cycling, seek operations, playback toggles, and system mock metrics.

---

## 2. Automated Test Suite (112 Assertions)

### Running the Test Suite
On macOS with Command Line Tools or Xcode:
```bash
make test
# or directly via SwiftPM:
swift run TestRunner
```

### Coverage of the 13 Core Verification Areas (Part C)
1. **Watchdog starts when panel becomes interactive**: Verified via `setPanelInteractive(true)` / `updateMouseRouting`.
2. **Watchdog does not create duplicate timers**: Verified via consecutive `startWatchdog()` calls.
3. **Pointer inside visible island keeps interaction enabled**: `panel.ignoresMouseEvents == false`.
4. **Pointer outside visible island disables interception**: `panel.ignoresMouseEvents == true`.
5. **Pointer outside visible island but inside fixed panel disables interception**: Verified at `(midX, maxY - 80)` in transparent strip.
6. **Panel is click-through before hover**: Initial `ignoresMouseEvents == true` and watchdog idle.
7. **Dragging a control preserves interaction until mouse-up**: `isCurrentlyDragging = true` protects slider scrubbing when cursor drifts outside island.
8. **Watchdog stops after restoring click-through**: Verified watchdog is deactivated when click-through is restored.
9. **Fixed panel frame never changes during state transitions**: Invariant across compact, expanded, and collapse states.
10. **Outward shoulder geometry is symmetric**: Left and right Bézier control points strictly mirror across `midX`.
11. **Curves use the hardware notch width**: Top opening exactly equals `notchWidth` (181 pt on 14" MBP).
12. **Upper shoulder curves meet side walls smoothly**: Tangent horizontal at bezel ($dy/dx = 0$), vertical at outer walls ($dx/dy = 0$).
13. **Compact and notchless geometries do not regress**: Compact notch and floating pill shapes remain intact.

```text
========================================
📊 RESULTS: 112 passed, 0 failed
========================================
```

---

## 3. Physical macOS Testing Protocol

Manual verification must be executed across four distinct fullscreen configurations:

### Scenario 1: Google Chrome Native Fullscreen
1. Open Google Chrome.
2. Enter fullscreen (`Control + Command + F`).
3. Hover cursor over Dynamic Island:
   - Dynamic Island expands smoothly.
4. Move cursor directly downward into web content.
5. Wait 2 seconds:
   - Dynamic Island click-through is immediately restored.
   - Chrome's toolbar and window controls auto-hide cleanly.
6. Repeat without visiting the Apple logo or battery icon.

### Scenario 2: Google Chrome YouTube Fullscreen
1. Open a video on YouTube in Google Chrome.
2. Click the YouTube fullscreen button (`f`).
3. Move cursor up to Dynamic Island:
   - Dynamic Island expands.
4. Move cursor directly downward into video playback:
   - Watchdog immediately sets `ignoresMouseEvents = true`.
   - YouTube/macOS fullscreen navigation controls and traffic lights auto-hide after native timeout.

### Scenario 3: Apple Safari Native Fullscreen
1. Open Safari.
2. Enter fullscreen (`Control + Command + F`).
3. Hover over Dynamic Island and move down into web content.
4. Verify Safari toolbar auto-hides without delay.

### Scenario 4: Apple Safari YouTube Fullscreen
1. Play YouTube video in Safari fullscreen mode.
2. Hover over Dynamic Island, click controls (play/pause, seek scrubber).
3. Move cursor directly downward into video.
4. Confirm fullscreen navigation controls and traffic lights auto-hide reliably.
