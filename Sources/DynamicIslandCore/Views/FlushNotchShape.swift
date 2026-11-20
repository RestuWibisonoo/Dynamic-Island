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

/// Bentuk garis tepi (outline) khusus untuk mode expanded:
/// Menggambar border HANYA pada sisi kiri, sudut kiri bawah, sisi bawah, sudut kanan bawah, dan sisi kanan.
/// Sisi atas DIBIARKAN TERBUKA TANPA GARIS agar menyatu sempurna 100% dengan bezel fisik MacBook tanpa garis ganda.
public struct ExpandedIslandOutlineShape: Shape {
    public var cornerRadius: CGFloat = 26
    public var hasHardwareNotch: Bool = true
    
    public init(cornerRadius: CGFloat = 26, hasHardwareNotch: Bool = true) {
        self.cornerRadius = cornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let safeRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
        
        if hasHardwareNotch {
            // Mulai dari sudut kiri atas (tanpa menggambar garis horizontal di atas)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Turun menyusuri sisi kiri
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - safeRadius))
            // Lengkungan sudut kiri bawah
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + safeRadius, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            // Garis bawah horizontal
            path.addLine(to: CGPoint(x: rect.maxX - safeRadius, y: rect.maxY))
            // Lengkungan sudut kanan bawah
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - safeRadius),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            // Naik menyusuri sisi kanan hingga sudut kanan atas
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            // TIDAK ADA path.closeSubpath() dan TIDAK ADA garis di atas!
        } else {
            // Pada layar tanpa notch, buat outline rounded rect penuh
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: safeRadius, height: safeRadius),
                style: .continuous
            )
        }
        
        return path
    }
}
