import XCTest
@testable import DynamicIslandCore

@MainActor
final class StateMachineTests: XCTestCase {
    
    func testInitialStateIsCompact() {
        let detector = ScreenDetector()
        let vm = IslandViewModel(screenDetector: detector)
        
        XCTAssertEqual(vm.state, .compact)
        XCTAssertFalse(vm.state.isExpanded)
        XCTAssertFalse(vm.state.isLocked)
        XCTAssertFalse(vm.isHovered)
    }
    
    func testExpandTransition() {
        let detector = ScreenDetector()
        let vm = IslandViewModel(screenDetector: detector)
        
        vm.transitionTo(state: .expanded(reason: .hover))
        
        XCTAssertEqual(vm.state, .expanded(reason: .hover))
        XCTAssertTrue(vm.state.isExpanded)
        XCTAssertFalse(vm.state.isLocked)
        XCTAssertTrue(vm.isHovered)
        XCTAssertEqual(vm.currentWidth, detector.currentMetrics.expandedWidth)
        XCTAssertEqual(vm.currentHeight, detector.currentMetrics.expandedHeight)
    }
    
    func testLockAndDismissLock() {
        let detector = ScreenDetector()
        let vm = IslandViewModel(screenDetector: detector)
        
        // Kunci buka
        vm.toggleLockOpen()
        XCTAssertEqual(vm.state, .expanded(reason: .locked))
        XCTAssertTrue(vm.state.isLocked)
        XCTAssertTrue(vm.state.isExpanded)
        
        // Hover out tidak boleh menutup island saat terkunci!
        vm.onHoverChanged(false)
        XCTAssertEqual(vm.state, .expanded(reason: .locked))
        
        // Tutup kunci
        vm.dismissLock()
        XCTAssertEqual(vm.state, .compact)
        XCTAssertFalse(vm.state.isExpanded)
    }
    
    func testToggleLockCyclesBetweenLockedAndCompact() {
        let detector = ScreenDetector()
        let vm = IslandViewModel(screenDetector: detector)
        
        XCTAssertEqual(vm.state, .compact)
        
        vm.toggleLockOpen()
        XCTAssertEqual(vm.state, .expanded(reason: .locked))
        
        vm.toggleLockOpen()
        XCTAssertEqual(vm.state, .compact)
    }
}
