import XCTest
@testable import DynamicIslandCore

final class GeometryTests: XCTestCase {
    
    func testNotchDisplayMetrics() {
        let metrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            hasHardwareNotch: true,
            rawNotchWidth: 179,
            safeAreaTop: 32
        )
        
        let expectedHeight = 32.0 + DesignTokens.Geometry.notchVerticalOffset
        XCTAssertTrue(metrics.hasHardwareNotch)
        XCTAssertEqual(metrics.notchHeight, expectedHeight)
        XCTAssertEqual(metrics.compactHeight, expectedHeight)
        // notchWidth = 179 + 2 = 181
        XCTAssertEqual(metrics.notchWidth, 181)
        // compactWidth = 181 + 76 * 2 = 333
        XCTAssertEqual(metrics.compactWidth, 333)
        
        // Compact Panel Frame
        let compactFrame = metrics.panelFrame(for: .compact)
        XCTAssertEqual(compactFrame.width, 333)
        XCTAssertEqual(compactFrame.height, expectedHeight)
        XCTAssertEqual(compactFrame.origin.x, (1470 - 333) / 2)
        XCTAssertEqual(compactFrame.origin.y, 956 - expectedHeight)
        XCTAssertEqual(compactFrame.maxY, 956)
        
        // Expanded Panel Frame
        let expandedFrame = metrics.panelFrame(for: .expanded(reason: .hover))
        XCTAssertEqual(expandedFrame.width, 460)
        XCTAssertEqual(expandedFrame.height, 220)
        XCTAssertEqual(expandedFrame.origin.x, (1470 - 460) / 2)
        XCTAssertEqual(expandedFrame.origin.y, 956 - 220)
        XCTAssertEqual(expandedFrame.maxY, 956)
        
        // Top anchor invariance
        XCTAssertEqual(compactFrame.maxY, expandedFrame.maxY)
    }
    
    func testNonNotchFloatingPillMetrics() {
        let metrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            hasHardwareNotch: false,
            rawNotchWidth: 0,
            safeAreaTop: 0
        )
        
        XCTAssertFalse(metrics.hasHardwareNotch)
        XCTAssertEqual(metrics.compactWidth, 180)
        XCTAssertEqual(metrics.compactHeight, 32)
        
        let compactFrame = metrics.panelFrame(for: .compact)
        XCTAssertEqual(compactFrame.origin.x, (1920 - 180) / 2)
        XCTAssertEqual(compactFrame.origin.y, 1080 - 32)
    }
    
    func testNegativeOriginMultiMonitorSupport() {
        // Layar eksternal yang diletakkan di sebelah kiri monitor utama (origin X = -1920)
        let metrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            hasHardwareNotch: false,
            rawNotchWidth: 0,
            safeAreaTop: 0
        )
        
        let compactFrame = metrics.panelFrame(for: .compact)
        let expectedX = -1920 + (1920 - 180) / 2
        XCTAssertEqual(compactFrame.origin.x, expectedX)
        XCTAssertEqual(compactFrame.origin.y, 1080 - 32)
    }
    
    func testFallbackMetricsSafety() {
        let fallback = IslandLayoutMetrics.fallback
        XCTAssertGreaterThan(fallback.screenFrame.width, 0)
        XCTAssertGreaterThan(fallback.screenFrame.height, 0)
        XCTAssertGreaterThan(fallback.compactWidth, 0)
        XCTAssertGreaterThan(fallback.compactHeight, 0)
    }
    
    func testHoverDetectionRectHysteresis() {
        let metrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            hasHardwareNotch: true,
            rawNotchWidth: 179,
            safeAreaTop: 32
        )
        
        let compactRect = metrics.hoverDetectionRect(for: .compact)
        let expandedRect = metrics.hoverDetectionRect(for: .expanded(reason: .hover))
        
        XCTAssertGreaterThan(compactRect.width, metrics.compactWidth)
        XCTAssertGreaterThan(expandedRect.width, metrics.expandedWidth)
        XCTAssertGreaterThan(expandedRect.width, compactRect.width)
        XCTAssertGreaterThan(expandedRect.height, compactRect.height)
        
        let centerTop = CGPoint(x: 1470 / 2, y: 956 - 16)
        XCTAssertTrue(compactRect.contains(centerTop))
        XCTAssertTrue(expandedRect.contains(centerTop))
    }
    
    func testFixedPanelArchitectureMetrics() {
        let metrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            hasHardwareNotch: true,
            rawNotchWidth: 179,
            safeAreaTop: 32
        )
        
        let expectedWidth = max(metrics.expandedWidth, metrics.compactWidth) + 60
        let expectedHeight = metrics.expandedHeight + 40
        XCTAssertEqual(metrics.fixedPanelWidth, expectedWidth)
        XCTAssertEqual(metrics.fixedPanelHeight, expectedHeight)
        
        let fixedFrame = metrics.fixedPanelFrame
        XCTAssertEqual(fixedFrame.width, expectedWidth)
        XCTAssertEqual(fixedFrame.height, expectedHeight)
        XCTAssertEqual(fixedFrame.origin.x, (1470 - expectedWidth) / 2)
        XCTAssertEqual(fixedFrame.origin.y, 956 - expectedHeight)
        XCTAssertEqual(fixedFrame.maxY, 956)
        
        // Visible island rect
        let compactVisible = metrics.visibleIslandRect(for: .compact)
        XCTAssertEqual(compactVisible.width, metrics.compactWidth)
        XCTAssertEqual(compactVisible.height, metrics.compactHeight + 6)
        XCTAssertEqual(compactVisible.maxY, 956 + 6)
        
        let expandedVisible = metrics.visibleIslandRect(for: .expanded(reason: .hover))
        XCTAssertEqual(expandedVisible.width, metrics.expandedWidth)
        XCTAssertEqual(expandedVisible.height, metrics.expandedHeight + 6)
        XCTAssertEqual(expandedVisible.maxY, 956 + 6)
    }
    
    func testSmoothNotchUpperCurvesAndOpenTop() {
        let shape = FlushNotchShape(
            topCornerRadius: 8,
            bottomCornerRadius: 26,
            hasHardwareNotch: true,
            isExpanded: true
        )
        let rect = CGRect(x: 0, y: 0, width: 460, height: 220)
        let fillPath = shape.path(in: rect)
        XCTAssertFalse(fillPath.isEmpty)
        
        let outline = ExpandedIslandOutlineShape(
            topCornerRadius: 8,
            bottomCornerRadius: 26,
            hasHardwareNotch: true
        )
        let outlinePath = outline.path(in: rect)
        XCTAssertFalse(outlinePath.isEmpty)
        XCTAssertGreaterThan(outlinePath.boundingRect.width, 400)
        XCTAssertGreaterThan(outlinePath.boundingRect.height, 200)
    }
    
    func testPanelFrameIdempotency() {
        let metrics = IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            hasHardwareNotch: true,
            rawNotchWidth: 179,
            safeAreaTop: 32
        )
        
        let frame1 = metrics.panelFrame(for: .compact)
        let frame2 = metrics.panelFrame(for: .compact)
        XCTAssertEqual(frame1, frame2)
    }
}
