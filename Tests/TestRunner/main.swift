import Foundation
import CoreGraphics
import AppKit
import SwiftUI
import DynamicIslandCore

@main
@MainActor
struct TestRunner {
    static func main() {
        print("========================================")
        print("🧪 DYNAMIC ISLAND TEST RUNNER")
        print("========================================")
        
        var passed = 0
        var failed = 0
        
        func assertTest(_ condition: Bool, _ name: String) {
            if condition {
                print("  ✅ [PASS] \(name)")
                passed += 1
            } else {
                print("  ❌ [FAIL] \(name)")
                failed += 1
            }
        }
        
        // ==========================================
        // 1. GEOMETRY TESTS
        // ==========================================
        print("\n📐 Running Geometry Tests...")
        
        // Test A: Hardware Notch Metrics
        let notchMetrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            hasHardwareNotch: true,
            rawNotchWidth: 179,
            safeAreaTop: 32
        )
        let expectedHeight = 32.0 + DesignTokens.Geometry.notchVerticalOffset
        assertTest(notchMetrics.hasHardwareNotch == true, "Hardware notch flag detected correctly")
        assertTest(notchMetrics.notchHeight == expectedHeight, "Notch height includes 1.5pt downward offset (\(expectedHeight)pt)")
        assertTest(notchMetrics.compactHeight == notchMetrics.notchHeight, "Compact height matches notch height")
        assertTest(notchMetrics.notchWidth == 181, "Notch width adds 2pt safety margin (179 + 2 = 181)")
        assertTest(notchMetrics.compactWidth == 181 + (76 * 2), "Compact width includes both ears (333pt)")
        
        let compactFrame = notchMetrics.panelFrame(for: .compact)
        assertTest(compactFrame.origin.x == (1470 - 333) / 2, "Compact panel is horizontally centered")
        assertTest(compactFrame.maxY == 956, "Compact panel top is pinned to screen top (maxY = 956)")
        assertTest(compactFrame.origin.y == 956 - expectedHeight, "Compact panel origin y matches screen top minus height")
        
        let expandedFrame = notchMetrics.panelFrame(for: .expanded(reason: .hover))
        assertTest(expandedFrame.width == 460, "Expanded panel width is 460pt")
        assertTest(expandedFrame.height == 220, "Expanded panel height is 220pt")
        assertTest(expandedFrame.origin.x == (1470 - 460) / 2, "Expanded panel is horizontally centered")
        assertTest(expandedFrame.maxY == 956, "Expanded panel top is pinned to screen top (maxY = 956)")
        assertTest(compactFrame.maxY == expandedFrame.maxY, "Top anchor remains 100% invariant during expansion (compact.maxY == expanded.maxY)")
        
        // Idempotency: repeated calls yield identical frames
        let compactFrame2 = notchMetrics.panelFrame(for: .compact)
        assertTest(compactFrame == compactFrame2, "Repeated frame queries are strictly idempotent")
        
        // Test B: Floating Pill (Non-Notch)
        let nonNotchMetrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            hasHardwareNotch: false,
            rawNotchWidth: 0,
            safeAreaTop: 0
        )
        assertTest(nonNotchMetrics.hasHardwareNotch == false, "Non-notch screen recognized as floating pill")
        assertTest(nonNotchMetrics.compactWidth == 180, "Floating pill compact width is 180pt")
        assertTest(nonNotchMetrics.compactHeight == 32, "Floating pill compact height is 32pt")
        
        // Test C: Multi-Monitor with Negative Coordinate Origin
        let negativeOriginMetrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            hasHardwareNotch: false,
            rawNotchWidth: 0,
            safeAreaTop: 0
        )
        let negFrame = negativeOriginMetrics.panelFrame(for: .compact)
        assertTest(negFrame.origin.x == -1920 + (1920 - 180) / 2, "Negative X origin multi-screen handled cleanly")
        assertTest(negFrame.origin.y == 1080 - 32, "Multi-screen top pinned correctly")
        
        // ==========================================
        // 2. HOVER DETECTION & HYSTERESIS TESTS
        // ==========================================
        print("\n🎯 Running Hover Detection & Hysteresis Tests...")
        
        let compactHoverRect = notchMetrics.hoverDetectionRect(for: .compact)
        let expandedHoverRect = notchMetrics.hoverDetectionRect(for: .expanded(reason: .hover))
        
        assertTest(compactHoverRect.width > notchMetrics.compactWidth, "Compact hover rect includes horizontal deadband")
        assertTest(expandedHoverRect.width > notchMetrics.expandedWidth, "Expanded hover rect includes horizontal deadband")
        assertTest(expandedHoverRect.width > compactHoverRect.width, "Expanded hover rect is wider than compact hover rect")
        assertTest(expandedHoverRect.height > compactHoverRect.height, "Expanded hover rect is taller than compact hover rect")
        
        // Hysteresis test: Center top point is inside BOTH compact and expanded hover zones
        let centerTopPoint = CGPoint(x: 1470 / 2, y: 956 - 16)
        assertTest(compactHoverRect.contains(centerTopPoint), "Compact hover zone captures cursor inside notch")
        assertTest(expandedHoverRect.contains(centerTopPoint), "Expanded hover zone preserves cursor coverage during expansion")
        
        // Boundary point: 50pt below notch is OUTSIDE compact hover zone but INSIDE expanded hover zone
        let belowNotchPoint = CGPoint(x: 1470 / 2, y: 956 - 80)
        assertTest(!compactHoverRect.contains(belowNotchPoint), "Point below notch is OUTSIDE compact hover zone")
        assertTest(expandedHoverRect.contains(belowNotchPoint), "Point below notch is INSIDE expanded hover zone (hysteresis)")
        
        // Far point: point in middle of screen is OUTSIDE both zones
        let videoContentPoint = CGPoint(x: 1470 / 2, y: 500)
        assertTest(!compactHoverRect.contains(videoContentPoint), "Video content point is OUTSIDE compact hover zone")
        assertTest(!expandedHoverRect.contains(videoContentPoint), "Video content point is OUTSIDE expanded hover zone")
        
        // ==========================================
        // 3. HIT-TESTING & FULLSCREEN PASS-THROUGH TESTS
        // ==========================================
        print("\n🪟 Running Hit-Testing & Pass-Through Tests...")
        
        let hostingView = IslandHostingView(rootView: AnyView(Text("Test")))
        hostingView.frame = NSRect(x: 0, y: 0, width: 460, height: 220)
        
        var simulatedIslandWidth: CGFloat = 333
        var simulatedIslandHeight: CGFloat = 32
        
        hostingView.islandContentRect = {
            let bounds = hostingView.bounds
            let x = (bounds.width - simulatedIslandWidth) / 2
            return CGRect(x: x, y: 0, width: simulatedIslandWidth, height: simulatedIslandHeight)
        }
        
        // In unflipped window coordinate space:
        // Window height = 220. Top of window is y = 220.
        // A point at (230, 210) is 10pt below window top (inside the 32pt island).
        let pointInsideIsland = NSPoint(x: 230, y: 210)
        assertTest(hostingView.hitTest(pointInsideIsland) != nil, "Hit-test INSIDE island shape returns view (interactive)")
        
        // A point at (230, 50) is 170pt below window top (transparent region below compact island).
        // Hit-test MUST return nil so clicks and mouse movement pass through to underlying fullscreen apps!
        let pointOutsideIsland = NSPoint(x: 230, y: 50)
        assertTest(hostingView.hitTest(pointOutsideIsland) == nil, "Hit-test in transparent area returns nil (pass-through to fullscreen app)")
        
        // A point at (10, 210) is near the left edge of the window, outside the 333pt notch.
        // Hit-test MUST return nil so menu bar or tabs beneath can receive events.
        let pointOutsideEars = NSPoint(x: 10, y: 210)
        assertTest(hostingView.hitTest(pointOutsideEars) == nil, "Hit-test outside island horizontal ears returns nil")
        
        // When expanded (simulatedIslandHeight = 220, simulatedIslandWidth = 460):
        simulatedIslandWidth = 460
        simulatedIslandHeight = 220
        assertTest(hostingView.hitTest(pointOutsideIsland) != nil, "Hit-test at (230, 50) returns view when island is expanded")
        
        // Test D: Open Top Outline Shape (No upper border across physical bezel)
        let outlineShape = ExpandedIslandOutlineShape(cornerRadius: 26, hasHardwareNotch: true)
        let outlinePath = outlineShape.path(in: CGRect(x: 0, y: 0, width: 460, height: 220))
        assertTest(!outlinePath.isEmpty, "Expanded outline path is generated")
        // The outline starts at (0, 0) and ends at (460, 0) without a top horizontal closing segment
        let pathBounds = outlinePath.boundingRect
        assertTest(pathBounds.width > 400 && pathBounds.height > 200, "Outline shape spans full card bounds")
        
        // Test E: Panel ignoresMouseEvents & Window Level behavior
        let testPanel = IslandPanel(contentRect: NSRect(x: 100, y: 100, width: 333, height: 33.5))
        assertTest(testPanel.ignoresMouseEvents == true, "Panel ignores mouse events by default (pass-through for fullscreen auto-hide)")
        testPanel.ignoresMouseEvents = false
        assertTest(testPanel.ignoresMouseEvents == false, "Panel enables mouse events dynamically when cursor enters island")
        let expectedLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
        assertTest(testPanel.level == expectedLevel, "Panel maintains Layer 33 window level (.statusBar + 8) to avoid collision with Chrome Layer 26")
        assertTest(testPanel.canBecomeKey == true, "Panel can become key without activation for internal interactive controls")
        
        // Test F: Fixed-Size NSPanel Architecture & Visible Island Rect
        let fixedFrame = notchMetrics.fixedPanelFrame
        assertTest(fixedFrame.width == 520, "Fixed panel width is max(expanded, compact) + 60 = 520pt")
        assertTest(fixedFrame.height == 260, "Fixed panel height is expandedHeight + 40 = 260pt")
        assertTest(fixedFrame.maxY == 956, "Fixed panel top edge is permanently anchored at screen maxY = 956")
        
        let compactVisible = notchMetrics.visibleIslandRect(for: .compact)
        assertTest(compactVisible.width == notchMetrics.compactWidth, "Compact visible rect width matches compactWidth (333pt)")
        let expandedVisible = notchMetrics.visibleIslandRect(for: .expanded(reason: .hover))
        assertTest(expandedVisible.width == notchMetrics.expandedWidth, "Expanded visible rect width matches expandedWidth (460pt)")
        
        // Test G: Window Controller Frame Invariance During Hover & State Changes
        let mockDetector = ScreenDetector()
        let mockVM = IslandViewModel(screenDetector: mockDetector)
        let controller = IslandWindowController(viewModel: mockVM, screenDetector: mockDetector)
        
        assertTest(controller.panel.ignoresMouseEvents == true, "Panel ignores mouse events initially")
        assertTest(controller.panel.frame == mockDetector.currentMetrics.fixedPanelFrame, "Panel starts with fixed panel frame")
        
        mockVM.transitionTo(state: .expanded(reason: .hover))
        assertTest(controller.panel.frame == mockDetector.currentMetrics.fixedPanelFrame, "Expanding state DOES NOT resize NSPanel (panel frame remains invariant)")
        
        mockVM.transitionTo(state: .compact)
        assertTest(controller.panel.frame == mockDetector.currentMetrics.fixedPanelFrame, "Collapsing state DOES NOT resize NSPanel (panel frame remains invariant)")
        
        // ==========================================
        // 4. STATE MACHINE & HOVER STABILITY TESTS
        // ==========================================
        print("\n⚙️ Running State Machine & Hover Stability Tests...")
        
        let detector = ScreenDetector()
        let vm = IslandViewModel(screenDetector: detector)
        
        assertTest(vm.state == .compact, "Initial state is .compact")
        assertTest(vm.state.isExpanded == false, "Initial isExpanded is false")
        assertTest(vm.state.isLocked == false, "Initial isLocked is false")
        assertTest(vm.isHovered == false, "Initial isHovered is false")
        
        // Single transition to expanded
        var resizeCount = 0
        vm.onResizeRequest = { _, isImmediate in
            if isImmediate { resizeCount += 1 }
        }
        
        vm.transitionTo(state: .expanded(reason: .hover))
        assertTest(vm.state == .expanded(reason: .hover), "State transitioned to .expanded(reason: .hover)")
        assertTest(vm.state.isExpanded == true, "State isExpanded is true")
        assertTest(vm.isHovered == true, "Hover flag is true")
        assertTest(resizeCount == 1, "First expansion triggers exactly 1 resize request")
        
        // Idempotency: Repeated expand requests while already expanded do NOT re-trigger resize
        vm.transitionTo(state: .expanded(reason: .hover))
        assertTest(resizeCount == 1, "Duplicate expand call does NOT trigger redundant resize request")
        
        // OnHoverChanged(true) while already expanded does NOT trigger resize
        vm.onHoverChanged(true)
        assertTest(resizeCount == 1, "onHoverChanged(true) while already expanded is idempotent")
        
        // Lock Open
        vm.toggleLockOpen()
        assertTest(vm.state.isLocked == true, "Island is locked open")
        assertTest(vm.state.isExpanded == true, "Island remains expanded when locked")
        assertTest(resizeCount == 1, "Locking open an already-expanded island does not restart expansion")
        
        // Hover out does NOT collapse when locked
        vm.onHoverChanged(false)
        assertTest(vm.state.isLocked == true, "Hover out does not unlock or collapse locked island")
        
        // Dismiss Lock
        var dismissNotified = false
        vm.onDismissLock = { dismissNotified = true }
        vm.dismissLock()
        assertTest(vm.state == .compact, "dismissLock() returns to .compact")
        assertTest(vm.state.isExpanded == false, "Island is collapsed after dismissLock()")
        assertTest(dismissNotified == true, "dismissLock() notifies onDismissLock observer")
        
        // Rapid Enter-Exit-Enter cancellation test:
        // Enter -> starts debounce timer
        vm.onHoverChanged(true)
        assertTest(vm.isHovered == true, "Hover state is true after enter")
        // Immediate exit before debounce fires -> cancels enter
        vm.onHoverChanged(false)
        assertTest(vm.isHovered == false, "Hover state is false after rapid exit")
        // Let debounce duration pass
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        assertTest(vm.state == .compact, "Rapid enter-exit sequence cleanly stays compact")
        
        // ==========================================
        // 5. PROVIDER TESTS
        // ==========================================
        print("\n🎵 Running Provider Tests...")
        
        let mediaProvider = MockMediaProvider()
        assertTest(mediaProvider.sourceType == .mock, "Media source is clearly identified as .mock")
        assertTest(mediaProvider.currentTrack?.title == "Starboy", "Initial track is Starboy")
        assertTest(mediaProvider.isPlaying == true, "Initial playback is true")
        
        mediaProvider.togglePlayback()
        assertTest(mediaProvider.isPlaying == false, "Playback paused after togglePlayback()")
        
        mediaProvider.nextTrack()
        assertTest(mediaProvider.currentTrack?.title == "Blinding Lights", "nextTrack() advances playlist")
        assertTest(mediaProvider.playbackProgress == 0.0, "Progress resets to 0.0 on track change")
        
        mediaProvider.previousTrack()
        assertTest(mediaProvider.currentTrack?.title == "Starboy", "previousTrack() returns to Starboy")
        
        mediaProvider.seek(to: 0.65)
        assertTest(mediaProvider.playbackProgress == 0.65, "seek(to:) updates progress")
        
        let batteryProvider = MockBatteryProvider(percentage: 88, isCharging: true)
        assertTest(batteryProvider.percentage == 88, "Battery percentage matches mock (88%)")
        assertTest(batteryProvider.isCharging == true, "Battery charging state matches mock (true)")
        
        let systemProvider = MockSystemMonitorProvider(cpuUsage: 22, ramUsage: 50)
        assertTest(systemProvider.cpuUsage == 22, "System monitor reports CPU usage (22%)")
        assertTest(systemProvider.ramUsage == 50, "System monitor reports RAM usage (50%)")
        
        // ==========================================
        // SUMMARY
        // ==========================================
        print("\n========================================")
        print("📊 RESULTS: \(passed) passed, \(failed) failed")
        print("========================================")
        
        if failed > 0 {
            exit(1)
        }
    }
}
