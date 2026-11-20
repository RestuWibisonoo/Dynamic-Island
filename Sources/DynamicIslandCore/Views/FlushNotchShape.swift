import SwiftUI

/// Bentuk geometri presisi yang menempel rata (*flush*) tanpa celah pada bezel atas MacBook
public struct FlushNotchShape: Shape {
    public var cornerRadius: CGFloat = 26
    public var hasHardwareNotch: Bool = true
    public var isExpanded: Bool = false
    
    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let safeRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
        
        if hasHardwareNotch {
            // Sisi atas rata dengan bezel atas layar MacBook
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - safeRadius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - safeRadius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + safeRadius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - safeRadius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        } else {
            // Mode kapsul melayang penuh
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: safeRadius, height: safeRadius),
                style: .continuous
            )
        }
        
        return path
    }
}
