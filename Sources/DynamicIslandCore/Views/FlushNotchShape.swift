import SwiftUI

/// Pembantu kalkulasi geometri kurva siluet notch MacBook
public enum NotchGeometryBuilder {
    /// Menghasilkan Path siluet pulau dengan lengkungan bahu keluar (outward-flaring cubic Bézier shoulders):
    /// - Pada Mac dengan notch saat expanded:
    ///   - Segmen tengah atas sejajar dengan lebar notch fisik hardware (`notchWidth`).
    ///   - Dari kedua ujung segmen notch, dibuat kurva bahu cubic Bézier simetris yang melebar KELUAR secara horizontal saat menurun (`shoulderHeight`).
    ///   - Kurva bahu menyatu mulus (tangent vertikal $C^1$) dengan dinding samping vertikal pulau yang lebih lebar.
    ///   - Dinding samping vertikal turun hingga lengkungan sudut bawah (`bottomRadius`).
    ///   - Sisi atas menempel rata (flush) dengan bezel fisik MacBook.
    ///   - Parameter `includeTopEdge`: jika true (untuk background fill dan clipShape), menambahkan garis horizontal atas dan menutup path.
    ///     Jika false (untuk outline specular border), segmen atas horizontal dibiarkan terbuka (open-top) agar menyatu mulus ke bezel tanpa garis ganda.
    public static func buildPath(
        in rect: CGRect,
        notchWidth: CGFloat,
        shoulderHeight: CGFloat = DesignTokens.Geometry.notchShoulderHeight,
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
                let actualShoulderHeight = min(shoulderHeight, rect.height / 3)
                let actualBottomRadius = min(bottomRadius, min(rect.width / 2, rect.height - actualShoulderHeight))
                
                let notchLeft = rect.midX - (actualNotchWidth / 2)
                let notchRight = rect.midX + (actualNotchWidth / 2)
                let dx = notchLeft - rect.minX
                let dy = actualShoulderHeight
                let tension = DesignTokens.Geometry.notchShoulderTension
                
                let startPoint = CGPoint(x: notchLeft, y: rect.minY)
                let shoulderLeftEnd = CGPoint(x: rect.minX, y: rect.minY + actualShoulderHeight)
                let shoulderRightStart = CGPoint(x: rect.maxX, y: rect.minY + actualShoulderHeight)
                let endPoint = CGPoint(x: notchRight, y: rect.minY)
                
                // 1. Mulai dari sisi kiri notch di tepi bezel
                path.move(to: startPoint)
                
                // 2. Bahu kiri melengkung keluar secara horizontal saat menurun (outward-flaring cubic Bézier)
                path.addCurve(
                    to: shoulderLeftEnd,
                    control1: CGPoint(x: notchLeft - dx * tension, y: rect.minY),
                    control2: CGPoint(x: rect.minX, y: rect.minY + dy * tension)
                )
                
                // 3. Dinding vertikal sisi kiri
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - actualBottomRadius))
                
                // 4. Sudut kiri bawah
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + actualBottomRadius, y: rect.maxY),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                
                // 5. Dinding horizontal bawah
                path.addLine(to: CGPoint(x: rect.maxX - actualBottomRadius, y: rect.maxY))
                
                // 6. Sudut kanan bawah
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.maxY - actualBottomRadius),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                
                // 7. Dinding vertikal sisi kanan naik ke bawah bahu kanan
                path.addLine(to: shoulderRightStart)
                
                // 8. Bahu kanan melengkung masuk ke sisi kanan notch di tepi bezel
                path.addCurve(
                    to: endPoint,
                    control1: CGPoint(x: rect.maxX, y: rect.minY + dy * tension),
                    control2: CGPoint(x: notchRight + dx * tension, y: rect.minY)
                )
                
                // 9. Segmen atas horizontal di sepanjang bezel fisik
                if includeTopEdge {
                    path.addLine(to: startPoint)
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

/// Bentuk geometri presisi yang menempel rata (*flush*) tanpa celah pada bezel atas MacBook
public struct FlushNotchShape: Shape {
    public var notchWidth: CGFloat
    public var shoulderHeight: CGFloat
    public var bottomCornerRadius: CGFloat
    public var hasHardwareNotch: Bool
    public var isExpanded: Bool
    
    public init(
        notchWidth: CGFloat = 181,
        shoulderHeight: CGFloat = DesignTokens.Geometry.notchShoulderHeight,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true,
        isExpanded: Bool = false
    ) {
        self.notchWidth = notchWidth
        self.shoulderHeight = shoulderHeight
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    // Inisialisasi kompatibilitas mundur
    public init(
        topCornerRadius: CGFloat,
        bottomCornerRadius: CGFloat,
        hasHardwareNotch: Bool,
        isExpanded: Bool = false
    ) {
        self.notchWidth = 181
        self.shoulderHeight = DesignTokens.Geometry.notchShoulderHeight
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
        self.shoulderHeight = DesignTokens.Geometry.notchShoulderHeight
        self.bottomCornerRadius = cornerRadius
        self.hasHardwareNotch = hasHardwareNotch
        self.isExpanded = isExpanded
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderHeight, bottomCornerRadius) }
        set {
            shoulderHeight = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        return NotchGeometryBuilder.buildPath(
            in: rect,
            notchWidth: notchWidth,
            shoulderHeight: shoulderHeight,
            bottomRadius: bottomCornerRadius,
            hasHardwareNotch: hasHardwareNotch,
            isExpanded: isExpanded,
            includeTopEdge: true
        )
    }
}

/// Bentuk garis tepi (outline) khusus untuk mode expanded:
/// Menggambar border pada bahu kiri keluar, sisi kiri vertikal, sudut kiri bawah, sisi bawah, sudut kanan bawah, sisi kanan vertikal, dan bahu kanan keluar.
/// Segmen atas horizontal DIBIARKAN TERBUKA TANPA GARIS agar menyatu sempurna 100% dengan bezel fisik MacBook tanpa garis ganda.
public struct ExpandedIslandOutlineShape: Shape {
    public var notchWidth: CGFloat
    public var shoulderHeight: CGFloat
    public var bottomCornerRadius: CGFloat
    public var hasHardwareNotch: Bool
    
    public init(
        notchWidth: CGFloat = 181,
        shoulderHeight: CGFloat = DesignTokens.Geometry.notchShoulderHeight,
        bottomCornerRadius: CGFloat = 26,
        hasHardwareNotch: Bool = true
    ) {
        self.notchWidth = notchWidth
        self.shoulderHeight = shoulderHeight
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    // Inisialisasi kompatibilitas mundur
    public init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat, hasHardwareNotch: Bool) {
        self.notchWidth = 181
        self.shoulderHeight = DesignTokens.Geometry.notchShoulderHeight
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    public init(cornerRadius: CGFloat = 26, hasHardwareNotch: Bool = true) {
        self.notchWidth = 181
        self.shoulderHeight = DesignTokens.Geometry.notchShoulderHeight
        self.bottomCornerRadius = cornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderHeight, bottomCornerRadius) }
        set {
            shoulderHeight = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    public func path(in rect: CGRect) -> Path {
        return NotchGeometryBuilder.buildPath(
            in: rect,
            notchWidth: notchWidth,
            shoulderHeight: shoulderHeight,
            bottomRadius: bottomCornerRadius,
            hasHardwareNotch: hasHardwareNotch,
            isExpanded: true,
            includeTopEdge: false
        )
    }
}
