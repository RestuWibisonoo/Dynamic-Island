import SwiftUI
import AppKit

/// Mengatur preferensi tema dan warna aksen agar menyatu dengan macOS
public enum IslandThemeMode: String, CaseIterable, Identifiable {
    case dark = "OLED Pure Black"
    case frostedGlass = "Frosted Glass (Vibrant)"
    case system = "Ikuti Tema macOS"
    
    public var id: String { rawValue }
}

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var themeMode: IslandThemeMode = .dark
    @Published public var accentColor: Color = Color(nsColor: .controlAccentColor)
    @Published public var customCornerRadius: CGFloat = 20
    
    private init() {}
    
    /// Background color untuk island container
    public var containerBackgroundColor: Color {
        switch themeMode {
        case .dark:
            return Color.black
        case .frostedGlass:
            return Color.black.opacity(0.85)
        case .system:
            return Color(nsColor: .windowBackgroundColor).opacity(0.92)
        }
    }
    
    /// Border stroke halus khas Apple
    public var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.06),
                Color.white.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
