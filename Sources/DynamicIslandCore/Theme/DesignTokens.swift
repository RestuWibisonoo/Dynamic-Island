import Foundation
import SwiftUI
import Combine

/// Token desain sistem terpusat untuk konsistensi UI/UX seluruh aplikasi
public enum DesignTokens {
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 6
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 14
        public static let xxl: CGFloat = 16
    }
    
    public enum Geometry {
        /// Penyesuaian vertikal ke bawah (dalam pt) agar menutupi tompel fisik notch 100% tanpa celah di atas
        public static let notchVerticalOffset: CGFloat = 1.5
        /// Kedalaman vertikal bahu lengkungan luar (outward shoulder) saat expanded (16-22pt)
        public static let notchShoulderDepth: CGFloat = 18.0
        /// Kompatibilitas alias untuk notchShoulderDepth
        public static let notchShoulderHeight: CGFloat = 18.0
        /// Ketegangan kurva bahu cubic Bézier (0.45 = natural smooth transition)
        public static let notchShoulderTension: CGFloat = 0.45
    }
    
    public enum CornerRadius {
        public static let compactNotchBottom: CGFloat = 12
        public static let compactPill: CGFloat = 16
        public static let expandedCard: CGFloat = 26
        /// Radius lengkungan sudut atas pulau saat mode expanded (transisi halus dari bezel notch fisik)
        public static let expandedNotchTop: CGFloat = 8
        public static let innerCard: CGFloat = 16
        public static let artwork: CGFloat = 12
        public static let capsule: CGFloat = 99
    }
    
    public enum AnimationDuration {
        public static let springResponse: Double = 0.36
        public static let springDamping: Double = 0.78
        public static let hoverEnterDebounce: Double = 0.12
        public static let hoverExitDelay: Double = 0.28
        public static let windowShrinkDelay: Double = 0.35
    }
}
