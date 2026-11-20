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
    
    public enum CornerRadius {
        public static let compactNotchBottom: CGFloat = 12
        public static let compactPill: CGFloat = 16
        public static let expandedCard: CGFloat = 26
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
