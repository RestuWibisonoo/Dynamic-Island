# Testing & Quality Assurance Documentation

## 1. Overview
The testing architecture is built on deterministic unit tests verifying:
1. **Geometry & Multi-Screen Positioning**: Hardware notch math, non-notch floating pill math, and negative origin coordinates.
2. **State Machine Invariants**: Initial compact state, hover expansion, lock-open enforcement, and hover-exit cancellation.
3. **Data Provider Contracts**: Track cycling, seek operations, playback toggles, and system mock metrics.

---

## 2. Test Execution

### Running the Test Suite
On macOS with Command Line Tools or Xcode:
```bash
make test
# or directly via SwiftPM:
swift run TestRunner
```

### Output Verification
Running `make test` executes 41 automated assertions:
```text
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
  ✅ [PASS] Non-notch screen recognized as floating pill
  ✅ [PASS] Floating pill compact width is 180pt
  ✅ [PASS] Floating pill compact height is 32pt
  ✅ [PASS] Negative X origin multi-screen handled cleanly
  ✅ [PASS] Multi-screen top pinned correctly

⚙️ Running State Machine Tests...
  ✅ [PASS] Initial state is .compact
  ✅ [PASS] Initial isExpanded is false
  ✅ [PASS] Initial isLocked is false
  ✅ [PASS] Initial isHovered is false
  ✅ [PASS] State transitioned to .expanded(reason: .hover)
  ✅ [PASS] State isExpanded is true
  ✅ [PASS] State isLocked is false
  ✅ [PASS] Hover flag is true
  ✅ [PASS] Island is locked open
  ✅ [PASS] Island remains expanded when locked
  ✅ [PASS] Hover out does not unlock or collapse locked island
  ✅ [PASS] dismissLock() returns to .compact
  ✅ [PASS] Island is collapsed after dismissLock()

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
📊 RESULTS: 41 passed, 0 failed
========================================
```

---

## 3. Environment Compatibility Notes
- On standalone macOS systems with Apple Command Line Tools (without full `/Applications/Xcode.app`), `XCTest.framework` is omitted by Apple's command-line distribution.
- To guarantee 100% testability on any developer machine or CI without requiring full Xcode.app GUI installation, the test suite uses `TestRunner` backed by `DynamicIslandCore`.
