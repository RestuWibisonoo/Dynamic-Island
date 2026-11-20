import AppKit

/// Representasi konteks layar dengan strategi pemilihan yang eksplisit
public struct DisplayContext: Equatable {
    public let screenFrame: NSRect
    public let visibleFrame: NSRect
    public let safeAreaTop: CGFloat
    public let hasHardwareNotch: Bool
    public let auxiliaryTopLeftWidth: CGFloat
    public let auxiliaryTopRightWidth: CGFloat
    
    public init(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        safeAreaTop: CGFloat,
        hasHardwareNotch: Bool,
        auxiliaryTopLeftWidth: CGFloat,
        auxiliaryTopRightWidth: CGFloat
    ) {
        self.screenFrame = screenFrame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.hasHardwareNotch = hasHardwareNotch
        self.auxiliaryTopLeftWidth = auxiliaryTopLeftWidth
        self.auxiliaryTopRightWidth = auxiliaryTopRightWidth
    }
    
    /// Membangun konteks dari NSScreen aktual
    @MainActor
    public static func from(screen: NSScreen) -> DisplayContext {
        let topInset = screen.safeAreaInsets.top
        let leftArea = screen.auxiliaryTopLeftArea
        let rightArea = screen.auxiliaryTopRightArea
        
        let hasNotch = topInset > 0 && leftArea != nil && rightArea != nil
        
        return DisplayContext(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaTop: topInset,
            hasHardwareNotch: hasNotch,
            auxiliaryTopLeftWidth: leftArea?.width ?? 0,
            auxiliaryTopRightWidth: rightArea?.width ?? 0
        )
    }
    
    /// Strategi pemilihan layar yang deterministik:
    /// 1. Prioritaskan layar internal MacBook yang memiliki hardware notch
    /// 2. Jika tidak ada layar notch (misal Mac Mini atau lid closed), pilih layar utama (NSScreen.main atau screens[0])
    @MainActor
    public static func selectTargetScreen(from screens: [NSScreen]) -> NSScreen? {
        // Cari layar yang memiliki notch hardware
        if let notchedScreen = screens.first(where: { $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil }) {
            return notchedScreen
        }
        // Fallback ke layar utama atau layar pertama
        return NSScreen.main ?? screens.first
    }
}
