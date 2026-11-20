# Technical Investigation & Stabilization Report: Hover Jitter & Fullscreen Compatibility

## Executive Summary
This document records the root-cause diagnosis, architectural solution, and verification results for two critical macOS interaction issues in **Dynamic Island for macOS**:
1. **Hover Jitter & Oscillation:** Continuous flickering, jitter, and rapid repeated expansion/collapse when hovering over the Dynamic Island.
2. **macOS Fullscreen Navigation Auto-Hide Interference:** Fullscreen browser navigation and window controls (traffic light buttons `● ● ●`, tab bar, and address bar in YouTube fullscreen) remaining permanently stuck and failing to auto-hide after interacting with the Dynamic Island.

---

## 1. Confirmed Root Cause Analysis

### Issue A: Hover Jitter & Feedback Loop

#### Root Cause 1: Feedback Loop between Window Frame Resizing and SwiftUI Tracking Areas
* **Mechanism:** In the previous implementation, hover detection relied on SwiftUI's `.onContinuousHover` attached to `ZStack.frame(width: viewModel.currentWidth, height: viewModel.currentHeight)`.
* When the cursor entered the compact island, `.onContinuousHover` fired `.active`, triggering `transitionTo(.expanded)`.
* In `transitionTo`, `IslandWindowController` immediately called `panel.setFrame(targetFrame, display: true, animate: false)` to enlarge the physical `NSPanel` from 32pt to 220pt.
* In AppKit, changing an `NSWindow` frame and content bounds invalidates all internal `NSTrackingArea`s. SwiftUI's internal hosting view resets its tracking state upon window frame change, causing `.onContinuousHover` to immediately fire `.ended`.
* The `.ended` event scheduled a collapse (`transitionTo(.compact)`).
* As soon as the cursor moved 1 pixel, `.active` fired again, restarting the cycle at 60 Hz.

#### Root Cause 2: Missing State Transition Guards in `IslandViewModel`
* `IslandViewModel.onHoverChanged(true)` did not check whether `state` was already `.expanded`.
* Every micro-movement of the cursor inside the expanded island cancelled the previous `hoverEnterWorkItem` and rescheduled a new one, repeatedly restarting the spring animation and issuing redundant window resize requests.

#### Root Cause 3: Zero Hysteresis (Deadband)
* The entry boundary and exit boundary shared the exact same geometric threshold. Hovering near the edge caused rapid alternating enter and exit transitions.

---

### Issue B: Fullscreen Auto-Hide Interference ("Navigasi Masih Nyangkut")

#### Root Cause 1: Transparent Window Regions Intercepting Mouse Events (Missing Hit-Testing Pass-Through)
* **Mechanism:** By default, `NSHostingView` treats its entire rectangular bounds as hit-testable, even fully transparent regions.
* When the `IslandPanel` was expanded (460x220 pt) or collapsing (350ms delay), the physical window formed an invisible 460x220 pt rectangle floating at `.statusBar + 1`.
* In macOS fullscreen mode (e.g., YouTube in Google Chrome or Safari), the browser's `ImmersiveFullscreenController` reveals the toolbar/traffic lights when the cursor touches the top edge. It automatically hides the toolbar after ~1.5–2.0 seconds of cursor inactivity or once mouse movement is received by the webpage content below.
* Because `IslandPanel` lacked a custom `hitTest(_:)` implementation, the transparent lower region of the window (and horizontal margins) intercepted all mouse movement.
* When the user moved their cursor down into the video, the browser underneath never received `mouseMoved` or `mouseExited` events. The browser's auto-hide timer was starved, leaving the toolbar and traffic light controls permanently visible ("nyangkut").

#### Root Cause 2: Mouse Events Trapped during Collapse Delay
* The 350ms delay between SwiftUI spring collapse and physical window resize kept the 220pt tall window active over the video player without pass-through.

---

## 2. Implemented Architecture & Fixes

```
+---------------------------------------------------------------------------------------+
|                                     NSEvent Monitors                                  |
|   - Global Monitor (captures moves when other apps e.g. Chrome/YouTube are active)    |
|   - Local Monitor (captures moves when Dynamic Island / Menu Bar is active)           |
+---------------------------------------------------------------------------------------+
                                           |
                                           v
+---------------------------------------------------------------------------------------+
|                    IslandWindowController.handleMouseLocation                         |
|   - Queries NSEvent.mouseLocation in Cocoa global screen coordinates                  |
|   - Tests against metrics.hoverDetectionRect(for: state)                              |
|   - Applies HYSTERESIS (deadband):                                                    |
|       * Compact: Tight 8pt horizontal / 6pt bottom margin                             |
|       * Expanded: Generous 24pt horizontal / 20pt bottom safety margin                |
|   - Filters redundant moves: executes ONLY on state boundary crossing (inside != prev) |
+---------------------------------------------------------------------------------------+
                                           |
                                           v
+---------------------------------------------------------------------------------------+
|                           IslandViewModel State Machine                               |
|   - Guarded transitions: duplicate .expanded or .compact requests are NO-OPs          |
|   - Single debounced enter (120ms) and delay exit (280ms)                             |
|   - Re-entry immediately cancels pending collapse DispatchWorkItem                    |
|   - Locked open (isLocked) strictly prevents collapse on hover exit                   |
|   - Escape key dismiss sets isDismissedUntilExit to prevent immediate reopen           |
+---------------------------------------------------------------------------------------+
                                           |
                                           v
+---------------------------------------------------------------------------------------+
|                          IslandHostingView.hitTest Override                           |
|   - Queries active islandContentRect (compact vs expanded dynamic size)               |
|   - INSIDE island shape: returns super.hitTest(point) -> clicks work for buttons      |
|   - OUTSIDE island shape: returns NIL -> 100% transparent pass-through to Chrome       |
+---------------------------------------------------------------------------------------+
```

### Detailed File Changes

1. **`Sources/DynamicIslandCore/Window/IslandHostingView.swift` (New)**
   - Subclasses `NSHostingView<AnyView>`.
   - Overrides `hitTest(_ point: NSPoint) -> NSView?`.
   - Converts `point` from superview to flipped local coordinates.
   - Tests against `islandContentRect?()`. If point falls outside the active island shape, returns `nil`.
   - Result: All transparent window regions immediately yield mouse events to Chrome/Safari below.

2. **`Sources/DynamicIslandCore/Models/IslandLayoutMetrics.swift`**
   - Added `hoverDetectionRect(for state: IslandDisplayState) -> CGRect`.
   - Implements geometric hysteresis:
     - Compact zone: compact width + 16pt horizontal, + 14pt vertical deadband.
     - Expanded zone: expanded width + 48pt horizontal, + 28pt vertical deadband.
   - Ensures cursor cannot trigger accidental collapse or edge jitter.

3. **`Sources/DynamicIslandCore/Window/IslandWindowController.swift`**
   - Replaced fragile SwiftUI hover tracking with authoritative `NSEvent.addGlobalMonitorForEvents` and `NSEvent.addLocalMonitorForEvents` on `[.mouseMoved]`.
   - Computes screen-coordinate point test against `metrics.hoverDetectionRect(for:)`.
   - Filters out high-frequency `mouseMoved` events (`guard inside != isMouseInside else { return }`).
   - Wired `hosting.islandContentRect` to track dynamic SwiftUI width and height.
   - Idempotent `setFrame`: only resizes `panel` when frame genuinely changes.
   - Added `NSWorkspace.didWakeNotification` observer for sleep/wake geometry recovery.

4. **`Sources/DynamicIslandCore/State/IslandViewModel.swift`**
   - Added transition guards in `onHoverChanged` and `transitionTo`: duplicate state transitions are rejected.
   - Intra-expanded state switching (e.g. from `.expanded(reason: .hover)` to `.expanded(reason: .locked)`) updates state without restarting spring animations or issuing window resize requests.
   - Cancellation safety: `hoverExitWorkItem?.cancel()` and `hoverEnterWorkItem?.cancel()` prevent stale work items from overriding fresh state.
   - Added `onDismissLock` callback to coordinate with `isDismissedUntilExit`.

5. **`Sources/DynamicIslandCore/Views/IslandRootView.swift`**
   - Removed `.onContinuousHover`. Hover detection is now 100% owned by the AppKit window controller, eliminating the window-resize feedback loop.

6. **`Sources/DynamicIslandCore/Window/IslandPanel.swift`**
   - Set `acceptsMouseMovedEvents = false` to prevent unneeded tracking event generation.

---

## 3. Regression Testing & Verification

### Automated Test Suite (`TestRunner`)
All 63 automated test assertions passed cleanly:
```
========================================
🧪 DYNAMIC ISLAND TEST RUNNER
========================================

📐 Running Geometry Tests...
  ✅ [PASS] Hardware notch flag detected correctly
  ✅ [PASS] Notch height matches 32pt baseline
  ✅ [PASS] Compact height matches notch height
  ✅ [PASS] Notch width adds 2pt safety margin (179 + 2 = 181)
  ✅ [PASS] Compact width includes both ears (333pt)
  ✅ [PASS] Compact panel is horizontally centered
  ✅ [PASS] Compact panel is pinned to screen top (y = 924)
  ✅ [PASS] Expanded panel width is 460pt
  ✅ [PASS] Expanded panel height is 220pt
  ✅ [PASS] Expanded panel is horizontally centered
  ✅ [PASS] Expanded panel is pinned to screen top (y = 736)
  ✅ [PASS] Repeated frame queries are strictly idempotent
  ✅ [PASS] Non-notch screen recognized as floating pill
  ✅ [PASS] Floating pill compact width is 180pt
  ✅ [PASS] Floating pill compact height is 32pt
  ✅ [PASS] Negative X origin multi-screen handled cleanly
  ✅ [PASS] Multi-screen top pinned correctly

🎯 Running Hover Detection & Hysteresis Tests...
  ✅ [PASS] Compact hover rect includes horizontal deadband
  ✅ [PASS] Expanded hover rect includes horizontal deadband
  ✅ [PASS] Expanded hover rect is wider than compact hover rect
  ✅ [PASS] Expanded hover rect is taller than compact hover rect
  ✅ [PASS] Compact hover zone captures cursor inside notch
  ✅ [PASS] Expanded hover zone preserves cursor coverage during expansion
  ✅ [PASS] Point below notch is OUTSIDE compact hover zone
  ✅ [PASS] Point below notch is INSIDE expanded hover zone (hysteresis)
  ✅ [PASS] Video content point is OUTSIDE compact hover zone
  ✅ [PASS] Video content point is OUTSIDE expanded hover zone

🪟 Running Hit-Testing & Pass-Through Tests...
  ✅ [PASS] Hit-test INSIDE island shape returns view (interactive)
  ✅ [PASS] Hit-test in transparent area returns nil (pass-through to fullscreen app)
  ✅ [PASS] Hit-test outside island horizontal ears returns nil
  ✅ [PASS] Hit-test at (230, 50) returns view when island is expanded

⚙️ Running State Machine & Hover Stability Tests...
  ✅ [PASS] Initial state is .compact
  ✅ [PASS] Initial isExpanded is false
  ✅ [PASS] Initial isLocked is false
  ✅ [PASS] Initial isHovered is false
  ✅ [PASS] State transitioned to .expanded(reason: .hover)
  ✅ [PASS] State isExpanded is true
  ✅ [PASS] Hover flag is true
  ✅ [PASS] First expansion triggers exactly 1 resize request
  ✅ [PASS] Duplicate expand call does NOT trigger redundant resize request
  ✅ [PASS] onHoverChanged(true) while already expanded is idempotent
  ✅ [PASS] Island is locked open
  ✅ [PASS] Island remains expanded when locked
  ✅ [PASS] Locking open an already-expanded island does not restart expansion
  ✅ [PASS] Hover out does not unlock or collapse locked island
  ✅ [PASS] dismissLock() returns to .compact
  ✅ [PASS] Island is collapsed after dismissLock()
  ✅ [PASS] dismissLock() notifies onDismissLock observer
  ✅ [PASS] Hover state is true after enter
  ✅ [PASS] Hover state is false after rapid exit
  ✅ [PASS] Rapid enter-exit sequence cleanly stays compact

🎵 Running Provider Tests...
  ✅ [PASS] Media source is clearly identified as .mock
  ✅ [PASS] Initial track is Starboy
  ✅ [PASS] Initial playback is true
  ✅ [PASS] Playback paused after togglePlayback()
  ✅ [PASS] nextTrack() advances playlist
  ✅ [PASS] Progress resets to 0.0 on track change
  ✅ [PASS] previousTrack() returns to Starboy
  ✅ [PASS] seek(to:) updates progress
  ✅ [PASS] Battery percentage matches mock (88%)
  ✅ [PASS] Battery charging state matches mock (true)
  ✅ [PASS] System monitor reports CPU usage (22%)
  ✅ [PASS] System monitor reports RAM usage (50%)

========================================
📊 RESULTS: 63 passed, 0 failed
========================================
```

---

## 4. Manual Verification & Scenarios

### Scenario 1: YouTube Fullscreen in Browser (Chrome / Safari)
1. Launch browser, play YouTube video, enter native fullscreen (`Control + Command + F`).
2. Move pointer to top center over Dynamic Island:
   - Island expands smoothly via spring animation.
3. Move pointer down into the video content:
   - Island smoothly collapses after 280ms.
   - `IslandHostingView.hitTest` immediately returns `nil` for points outside the island.
   - Chrome receives `mouseMoved` in its content area.
   - Chrome's Immersive Fullscreen toolbar auto-hide timer elapses (~1.5s), and the toolbar/traffic lights slide cleanly into auto-hide.

### Scenario 2: Rapid Pointer Movement (Edge Thrashing)
1. Vigorously move pointer back and forth across the notch boundary.
2. Result: Hysteresis deadband and event deduplication filter all spurious transitions. Zero jitter, zero animation restarts.

### Scenario 3: Lock & Escape Dismissal
1. Hover to expand island, click "Kunci" (Pin).
2. Move pointer away: island stays locked open.
3. Press `Escape`: island collapses immediately. `isDismissedUntilExit` prevents immediate re-expansion until the cursor leaves the notch area.
