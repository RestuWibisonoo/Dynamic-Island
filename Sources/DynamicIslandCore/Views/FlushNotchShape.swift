import SwiftUI

/// Pembantu kalkulasi geometri kurva siluet notch MacBook
public enum NotchGeometryBuilder {
    /// Menghasilkan Path siluet pulau:
    /// - Pada Mac dengan notch:
    ///   - Sisi atas menempel rata (flush) dengan bezel fisik MacBook.
    ///   - Saat expanded, sudut kiri atas dan kanan atas memiliki lengkungan halus (topRadius: ~6-8pt).
    ///   - Sudut kiri bawah dan kanan bawah memiliki lengkungan rounded card (bottomRadius: ~26pt).
    ///   - Parameter `includeTopEdge`: jika true (untuk background fill dan clipShape), menambahkan garis horizontal atas dan menutup path.
    ///     Jika false (untuk outline specular border), sisi atas dibiarkan terbuka (open-top) agar menyatu mulus ke bezel tanpa garis ganda.
    public static func buildPath(
        in rect: CGRect,
        topRadius: CGFloat,
        bottomRadius: CGFloat,
        hasHardwareNotch: Bool,
        includeTopEdge: Bool
    ) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }
        
        if hasHardwareNotch {
            let maxRadius = min(rect.width / 2, rect.height)
            let actualTopRadius = min(max(topRadius, 0), maxRadius)
            let actualBottomRadius = min(max(bottomRadius, 0), min(rect.width / 2, max(rect.height - actualTopRadius, 0)))
            
            let startTopLeft = CGPoint(x: rect.minX + actualTopRadius, y: rect.minY)
            let endTopRight = CGPoint(x: rect.maxX - actualTopRadius, y: rect.minY)
            
            // 1. Mulai dari titik temu lengkungan kiri-atas dengan bezel atas
            path.move(to: startTopLeft)
            
            // 2. Lengkungan sudut kiri-atas (dari horizontal bezel ke vertikal sisi kiri)
            if actualTopRadius > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.minY + actualTopRadius),
                    control: CGPoint(x: rect.minX, y: rect.minY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            }
            
            // 3. Sisi kiri vertikal
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - actualBottomRadius))
            
            // 4. Lengkungan sudut kiri-bawah
            if actualBottomRadius > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + actualBottomRadius, y: rect.maxY),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            }
            
            // 5. Sisi bawah horizontal
            path.addLine(to: CGPoint(x: rect.maxX - actualBottomRadius, y: rect.maxY))
            
            // 6. Lengkungan sudut kanan-bawah
            if actualBottomRadius > 0 {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.maxY - actualBottomRadius),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            
            // 7. Sisi kanan vertikal naik
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + actualTopRadius))
            
            // 8. Lengkungan sudut kanan-atas (dari vertikal sisi kanan ke horizontal bezel)
            if actualTopRadius > 0 {
                path.addQuadCurve(
                    to: endTopRight,
                    control: CGPoint(x: rect.maxX, y: rect.minY)
                )
            } else {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            }
            
            // 9. Penutupan sisi atas (HANYA untuk fill dan clipping)
            if includeTopEdge {
                path.addLine(to: startTopLeft)
                path.closeSubpath()
            }
        } else {
            // Mode kapsul melayang pada Mac tanpa notch
            let safeRadius = min(bottomRadius, min(rect.width, rect.height) / 2)
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: safeRadius, height: safeRadius),
                style: .continuous
            )
        }
        
        return path
    }
}

/// Bentuk geometri presisi yang menempel rata (*flush*) tanpa celah pada bezel atas MacBook
public struct FlushNotchShape: Shape {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat
    public var hasHardwareNotch: Bool
    public var isExpanded: Bool
    
    public init(
        topCornerRadius: CGFloat = 8,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true,
        isExpanded: Bool = false
    ) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    // Inisialisasi kompatibilitas mundur
    public init(
        cornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true,
        isExpanded: Bool = false
    ) {
        self.topCornerRadius = isExpanded ? DesignTokens.CornerRadius.expandedNotchTop : 0
        self.bottomCornerRadius = cornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        let effectiveTop = hasHardwareNotch ? (isExpanded ? topCornerRadius : 0) : 0
        return NotchGeometryBuilder.buildPath(
            in: rect,
            topRadius: effectiveTop,
            bottomRadius: bottomCornerRadius,
            hasHardwareNotch: hasHardwareNotch,
            includeTopEdge: true
        )
    }
}

/// Bentuk garis tepi (outline) khusus untuk mode expanded:
/// Menggambar border pada lengkungan sudut kiri atas, sisi kiri, sudut kiri bawah, sisi bawah, sudut kanan bawah, sisi kanan, dan sudut kanan atas.
/// Sisi atas horizontal DIBIARKAN TERBUKA TANPA GARIS agar menyatu sempurna 100% dengan bezel fisik MacBook tanpa garis ganda.
public struct ExpandedIslandOutlineShape: Shape {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat
    public var hasHardwareNotch: Bool
    
    public init(
        topCornerRadius: CGFloat = 8,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true
    ) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    // Inisialisasi kompatibilitas mundur
    public init(cornerRadius: CGFloat = 26, hasHardwareNotch: Bool = true) {
        self.topCornerRadius = DesignTokens.CornerRadius.expandedNotchTop
        self.bottomCornerRadius = cornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        return NotchGeometryBuilder.buildPath(
            in: rect,
            topRadius: hasHardwareNotch ? topCornerRadius : 0,
            bottomRadius: bottomCornerRadius,
            hasHardwareNotch: hasHardwareNotch,
            includeTopEdge: false
        )
    }
}
