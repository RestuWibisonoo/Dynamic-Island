import SwiftUI
import AppKit

/// Mengatur preferensi tema dan warna aksen agar menyatu dengan macOS
public enum IslandThemeMode: String, CaseIterable, Identifiable, Sendable {
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
    
    public init() {}
    
    /// Warna latar belakang untuk kontainer pulau
    public var containerBackgroundColor: Color {
        switch themeMode {
        case .dark:
            return Color.black
        case .frostedGlass:
            return Color.black.opacity(0.82)
        case .system:
            return Color(nsColor: .windowBackgroundColor).opacity(0.95)
        }
    }
    
    /// Border gradient specular halus khas Apple
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
