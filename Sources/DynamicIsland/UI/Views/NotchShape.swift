import SwiftUI

/// Bentuk geometri presisi yang menempel rata (*flush*) tanpa celah pada bezel atas MacBook:
/// - Pada MacBook dengan Notch: Sisi atas 100% rata (top corners = 0) agar menyatu tanpa celah dengan bezel layar,
///   dan kedua sudut bawah melengkung kontinu (*continuous squircle* 26pt).
/// - Pada Mac tanpa Notch / Floating Pill: Semua sudut membulat penuh seperti kapsul melayang.
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
        
        if hasHardwareNotch {
            // Sisi atas menempel rapat pada bezel fisik layar MacBook (tanpa celah menu bar)
            let bottomRadius = cornerRadius
            
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Garis lurus atas menyusuri bezel monitor
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Garis vertikal sisi kanan
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
            // Lengkungan bawah kanan (squircle)
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            // Garis lurus bawah
            path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
            // Lengkungan bawah kiri (squircle)
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            // Garis vertikal sisi kiri kembali ke bezel atas
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        } else {
            // Mode kapsul melayang untuk monitor eksternal / Mac tanpa notch
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
                style: .continuous
            )
        }
        
        return path
    }
}
