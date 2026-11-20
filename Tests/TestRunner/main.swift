import Foundation
import CoreGraphics
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
        assertTest(notchMetrics.hasHardwareNotch == true, "Hardware notch flag detected correctly")
        assertTest(notchMetrics.notchHeight == 32, "Notch height matches 32pt baseline")
        assertTest(notchMetrics.compactHeight == 32, "Compact height matches notch height")
        assertTest(notchMetrics.notchWidth == 181, "Notch width adds 2pt safety margin (179 + 2 = 181)")
        assertTest(notchMetrics.compactWidth == 181 + (76 * 2), "Compact width includes both ears (333pt)")
        
        let compactFrame = notchMetrics.panelFrame(for: .compact)
        assertTest(compactFrame.origin.x == (1470 - 333) / 2, "Compact panel is horizontally centered")
        assertTest(compactFrame.origin.y == 956 - 32, "Compact panel is pinned to screen top (y = 924)")
        
        let expandedFrame = notchMetrics.panelFrame(for: .expanded(reason: .hover))
        assertTest(expandedFrame.width == 460, "Expanded panel width is 460pt")
        assertTest(expandedFrame.height == 220, "Expanded panel height is 220pt")
        assertTest(expandedFrame.origin.x == (1470 - 460) / 2, "Expanded panel is horizontally centered")
        assertTest(expandedFrame.origin.y == 956 - 220, "Expanded panel is pinned to screen top (y = 736)")
        
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
        // 2. STATE MACHINE TESTS
        // ==========================================
        print("\n⚙️ Running State Machine Tests...")
        
        let detector = ScreenDetector()
        let vm = IslandViewModel(screenDetector: detector)
        
        assertTest(vm.state == .compact, "Initial state is .compact")
        assertTest(vm.state.isExpanded == false, "Initial isExpanded is false")
        assertTest(vm.state.isLocked == false, "Initial isLocked is false")
        assertTest(vm.isHovered == false, "Initial isHovered is false")
        
        // Transition to Expanded
        vm.transitionTo(state: .expanded(reason: .hover))
        assertTest(vm.state == .expanded(reason: .hover), "State transitioned to .expanded(reason: .hover)")
        assertTest(vm.state.isExpanded == true, "State isExpanded is true")
        assertTest(vm.state.isLocked == false, "State isLocked is false")
        assertTest(vm.isHovered == true, "Hover flag is true")
        
        // Lock Open
        vm.toggleLockOpen()
        assertTest(vm.state.isLocked == true, "Island is locked open")
        assertTest(vm.state.isExpanded == true, "Island remains expanded when locked")
        
        // Hover out does NOT collapse when locked
        vm.onHoverChanged(false)
        assertTest(vm.state.isLocked == true, "Hover out does not unlock or collapse locked island")
        
        // Dismiss Lock
        vm.dismissLock()
        assertTest(vm.state == .compact, "dismissLock() returns to .compact")
        assertTest(vm.state.isExpanded == false, "Island is collapsed after dismissLock()")
        
        // ==========================================
        // 3. PROVIDER TESTS
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
