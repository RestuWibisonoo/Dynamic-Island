import Foundation
import CoreGraphics

/// Model geometri terpusat (*Single Source of Truth*) untuk seluruh perhitungan dimensi dan koordinat Dynamic Island
public struct IslandLayoutMetrics: Equatable, Sendable {
    public let screenFrame: CGRect
    public let hasHardwareNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    public let earWidth: CGFloat
    
    public let compactWidth: CGFloat
    public let compactHeight: CGFloat
    public let expandedWidth: CGFloat
    public let expandedHeight: CGFloat
    
    public init(
        screenFrame: CGRect,
        hasHardwareNotch: Bool,
        rawNotchWidth: CGFloat,
        safeAreaTop: CGFloat,
        earWidth: CGFloat = 76,
        expandedWidth: CGFloat = 460,
        expandedHeight: CGFloat = 220
    ) {
        self.screenFrame = screenFrame
        self.hasHardwareNotch = hasHardwareNotch
        self.earWidth = earWidth
        self.expandedWidth = expandedWidth
        self.expandedHeight = expandedHeight
        
        if hasHardwareNotch {
            // Lebar notch hardware + toleransi 2pt
            self.notchWidth = max(rawNotchWidth + 2.0, 180)
            // Tinggi notch hardware pas 32.0pt (atau safeAreaTop)
            self.notchHeight = max(safeAreaTop, 32.0)
            self.compactWidth = self.notchWidth + (earWidth * 2)
            self.compactHeight = self.notchHeight
        } else {
            // Mode Floating Pill pada layar tanpa notch
            self.notchWidth = 180
            self.notchHeight = 32.0
            self.compactWidth = 180
            self.compactHeight = 32.0
        }
    }
    
    /// Menghitung frame NSPanel di koordinat global AppKit (mendukung multi-monitor dengan origin negatif X/Y)
    public func panelFrame(for state: IslandDisplayState) -> CGRect {
        let width = state.isExpanded ? expandedWidth : compactWidth
        let height = state.isExpanded ? expandedHeight : compactHeight
        
        let x = screenFrame.origin.x + (screenFrame.width - width) / 2
        let y = screenFrame.origin.y + screenFrame.height - height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Fallback default jika layar belum terdeteksi
    public static var fallback: IslandLayoutMetrics {
        IslandLayoutMetrics(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            hasHardwareNotch: true,
            rawNotchWidth: 179,
            safeAreaTop: 32
        )
    }
}
