import XCTest
@testable import DynamicIslandCore

@MainActor
final class ProviderTests: XCTestCase {
    
    func testMockMediaProviderControls() {
        let provider = MockMediaProvider()
        
        XCTAssertEqual(provider.sourceType, .mock)
        XCTAssertEqual(provider.currentTrack?.title, "Starboy")
        XCTAssertTrue(provider.isPlaying)
        
        // Test Play / Pause toggle
        provider.togglePlayback()
        XCTAssertFalse(provider.isPlaying)
        provider.togglePlayback()
        XCTAssertTrue(provider.isPlaying)
        
        // Test Next Track
        provider.nextTrack()
        XCTAssertEqual(provider.currentTrack?.title, "Blinding Lights")
        XCTAssertEqual(provider.playbackProgress, 0.0)
        
        // Test Previous Track
        provider.previousTrack()
        XCTAssertEqual(provider.currentTrack?.title, "Starboy")
        
        // Test Seek
        provider.seek(to: 0.75)
        XCTAssertEqual(provider.playbackProgress, 0.75)
    }
    
    func testMockBatteryProvider() {
        let provider = MockBatteryProvider(percentage: 85, isCharging: false)
        XCTAssertEqual(provider.percentage, 85)
        XCTAssertFalse(provider.isCharging)
        
        provider.update(percentage: 100, isCharging: true)
        XCTAssertEqual(provider.percentage, 100)
        XCTAssertTrue(provider.isCharging)
    }
    
    func testMockSystemMonitorProvider() {
        let provider = MockSystemMonitorProvider(cpuUsage: 25, ramUsage: 55)
        XCTAssertEqual(provider.cpuUsage, 25)
        XCTAssertEqual(provider.ramUsage, 55)
        
        provider.update(cpu: 30, ram: 60)
        XCTAssertEqual(provider.cpuUsage, 30)
        XCTAssertEqual(provider.ramUsage, 60)
    }
}
