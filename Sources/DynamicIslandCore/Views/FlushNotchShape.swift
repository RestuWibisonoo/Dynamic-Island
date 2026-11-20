import SwiftUI

/// Generator Geometri Siluet Dynamic Island (Single Source of Truth)
public enum IslandSilhouette {
    /// Menghasilkan Path siluet pulau dengan lengkungan bahu keluar kontinu (outward continuous curve):
    /// - Pada Mac dengan notch saat expanded:
    ///   - Segmen tengah atas sejajar dengan lebar notch fisik hardware (`notchWidth`).
    ///   - Dari kedua ujung segmen notch, dibuat kurva bahu cubic Bézier simetris yang melebar KELUAR secara horizontal saat menurun (`shoulderDepth`).
    ///   - Kurva bahu menyatu mulus (tangent vertikal $C^1$) dengan dinding samping vertikal pulau yang lebih lebar.
    ///   - Dinding samping vertikal turun hingga lengkungan sudut bawah (`bottomRadius`).
    ///   - Parameter `includeTopEdge`: jika true (untuk background fill dan clipShape), menambahkan garis horizontal atas dan menutup path.
    ///     Jika false (untuk outline specular border), segmen atas horizontal dibiarkan terbuka (open-top) agar menyatu mulus ke bezel tanpa garis ganda.
    public static func path(
        in rect: CGRect,
        notchWidth: CGFloat,
        shoulderDepth: CGFloat = DesignTokens.Geometry.notchShoulderDepth,
        bottomRadius: CGFloat = DesignTokens.CornerRadius.expandedCard,
        hasHardwareNotch: Bool,
        isExpanded: Bool,
        includeTopEdge: Bool
    ) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }
        
        if hasHardwareNotch {
            if isExpanded && rect.width > notchWidth {
                let actualNotchWidth = min(notchWidth, rect.width)
                let safeShoulderDepth = min(max(shoulderDepth, 0), rect.height / 3)
                let safeBottomRadius = min(max(bottomRadius, 0), min(rect.width / 2, rect.height - safeShoulderDepth))
                
                let midX = rect.midX
                let neckLeft = midX - (actualNotchWidth / 2)
                let neckRight = midX + (actualNotchWidth / 2)
                let shoulderY = rect.minY + safeShoulderDepth
                let leftSpan = max(neckLeft - rect.minX, 0)
                let rightSpan = max(rect.maxX - neckRight, 0)
                let tension: CGFloat = DesignTokens.Geometry.notchShoulderTension
                
                if includeTopEdge {
                    // 1. Mulai dari (neckLeft, rect.minY)
                    path.move(to: CGPoint(x: neckLeft, y: rect.minY))
                    // 2. Segmen tengah atas ke (neckRight, rect.minY)
                    path.addLine(to: CGPoint(x: neckRight, y: rect.minY))
                } else {
                    // Mode outline: mulai langsung dari neckRight tanpa garis horizontal penutup di atas
                    path.move(to: CGPoint(x: neckRight, y: rect.minY))
                }
                
                // 3. Kurva cubic bahu KANAN keluar ke (rect.maxX, shoulderY)
                // Tangent awal horizontal di bezel (dy=0), tangent akhir vertikal di dinding samping (dx=0)
                path.addCurve(
                    to: CGPoint(x: rect.maxX, y: shoulderY),
                    control1: CGPoint(x: neckRight + rightSpan * tension, y: rect.minY),
                    control2: CGPoint(x: rect.maxX, y: shoulderY - safeShoulderDepth * tension)
                )
                
                // 4. Dinding vertikal sisi kanan turun
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - safeBottomRadius))
                
                // 5. Lengkungan sudut kanan bawah
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - safeBottomRadius, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                
                // 6. Segmen horizontal bawah
                path.addLine(to: CGPoint(x: rect.minX + safeBottomRadius, y: rect.maxY))
                
                // 7. Lengkungan sudut kiri bawah
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - safeBottomRadius),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                
                // 8. Dinding vertikal sisi kiri naik ke (rect.minX, shoulderY)
                path.addLine(to: CGPoint(x: rect.minX, y: shoulderY))
                
                // 9. Kurva cubic bahu KIRI keluar kembali ke (neckLeft, rect.minY)
                // Tangent awal vertikal dari dinding samping (dx=0), tangent akhir horizontal di bezel (dy=0)
                path.addCurve(
                    to: CGPoint(x: neckLeft, y: rect.minY),
                    control1: CGPoint(x: rect.minX, y: shoulderY - safeShoulderDepth * tension),
                    control2: CGPoint(x: neckLeft - leftSpan * tension, y: rect.minY)
                )
                
                // 10. Tutup path jika includeTopEdge true
                if includeTopEdge {
                    path.closeSubpath()
                }
            } else {
                // Mode Compact pada Mac dengan notch:
                // Sisi atas rata dengan bezel, dinding samping turun lurus, sudut bawah melengkung
                let safeBottomRadius = min(bottomRadius, min(rect.width / 2, rect.height))
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - safeBottomRadius))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - safeBottomRadius, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX + safeBottomRadius, y: rect.maxY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - safeBottomRadius),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.closeSubpath()
            }
        } else {
            // Mode kapsul melayang penuh pada Mac tanpa notch
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

/// Pembantu kalkulasi geometri kurva siluet notch MacBook (Kompatibilitas Penuh)
public enum NotchGeometryBuilder {
    public static func buildPath(
        in rect: CGRect,
        notchWidth: CGFloat,
        shoulderHeight: CGFloat = DesignTokens.Geometry.notchShoulderDepth,
        bottomRadius: CGFloat = DesignTokens.CornerRadius.expandedCard,
        hasHardwareNotch: Bool,
        isExpanded: Bool,
        includeTopEdge: Bool
    ) -> Path {
        return IslandSilhouette.path(
            in: rect,
            notchWidth: notchWidth,
            shoulderDepth: shoulderHeight,
            bottomRadius: bottomRadius,
            hasHardwareNotch: hasHardwareNotch,
            isExpanded: isExpanded,
            includeTopEdge: includeTopEdge
        )
    }
}

/// Bentuk geometri presisi yang menempel rata (*flush*) tanpa celah pada bezel atas MacBook
public struct FlushNotchShape: Shape {
    public var notchWidth: CGFloat
    public var shoulderDepth: CGFloat
    public var bottomCornerRadius: CGFloat
    public var hasHardwareNotch: Bool
    public var isExpanded: Bool
    
    public init(
        notchWidth: CGFloat = 181,
        shoulderDepth: CGFloat = DesignTokens.Geometry.notchShoulderDepth,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true,
        isExpanded: Bool = false
    ) {
        self.notchWidth = notchWidth
        self.shoulderDepth = shoulderDepth
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    // Inisialisasi kompatibilitas mundur
    public init(
        notchWidth: CGFloat = 181,
        shoulderHeight: CGFloat,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true,
        isExpanded: Bool = false
    ) {
        self.notchWidth = notchWidth
        self.shoulderDepth = shoulderHeight
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    public init(
        topCornerRadius: CGFloat,
        bottomCornerRadius: CGFloat,
        hasHardwareNotch: Bool,
        isExpanded: Bool = false
    ) {
        self.notchWidth = 181
        self.shoulderDepth = DesignTokens.Geometry.notchShoulderDepth
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    public init(
        cornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true,
        isExpanded: Bool = false
    ) {
        self.notchWidth = 181
        self.shoulderDepth = DesignTokens.Geometry.notchShoulderDepth
        self.bottomCornerRadius = cornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderDepth, bottomCornerRadius) }
        set {
            shoulderDepth = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        return IslandSilhouette.path(
            in: rect,
            notchWidth: notchWidth,
            shoulderDepth: shoulderDepth,
            bottomRadius: bottomCornerRadius,
            hasHardwareNotch: hasHardwareNotch,
            isExpanded: isExpanded,
            includeTopEdge: true
        )
    }
}

/// Bentuk garis tepi (outline) khusus untuk mode expanded:
/// Menggambar border pada bahu kanan keluar, dinding samping kanan, sudut kanan bawah, sisi bawah, sudut kiri bawah, dinding samping kiri, dan bahu kiri keluar.
/// Segmen atas horizontal DIBIARKAN TERBUKA TANPA GARIS agar menyatu sempurna 100% dengan bezel fisik MacBook tanpa garis ganda.
public struct ExpandedIslandOutlineShape: Shape {
    public var notchWidth: CGFloat
    public var shoulderDepth: CGFloat
    public var bottomCornerRadius: CGFloat
    public var hasHardwareNotch: Bool
    
    public init(
        notchWidth: CGFloat = 181,
        shoulderDepth: CGFloat = DesignTokens.Geometry.notchShoulderDepth,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true
    ) {
        self.notchWidth = notchWidth
        self.shoulderDepth = shoulderDepth
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    // Inisialisasi kompatibilitas mundur
    public init(
        notchWidth: CGFloat = 181,
        shoulderHeight: CGFloat,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true
    ) {
        self.notchWidth = notchWidth
        self.shoulderDepth = shoulderHeight
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    public init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat, hasHardwareNotch: Bool) {
        self.notchWidth = 181
        self.shoulderDepth = DesignTokens.Geometry.notchShoulderDepth
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    public init(cornerRadius: CGFloat = 26, hasHardwareNotch: Bool = true) {
        self.notchWidth = 181
        self.shoulderDepth = DesignTokens.Geometry.notchShoulderDepth
        self.bottomCornerRadius = cornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderDepth, bottomCornerRadius) }
        set {
            shoulderDepth = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        return IslandSilhouette.path(
            in: rect,
            notchWidth: notchWidth,
            shoulderDepth: shoulderDepth,
            bottomRadius: bottomCornerRadius,
            hasHardwareNotch: hasHardwareNotch,
            isExpanded: true,
            includeTopEdge: false
        )
    }
}
