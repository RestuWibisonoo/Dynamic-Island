import AppKit
import Combine
import os.log

/// Mendeteksi perubahan konfigurasi layar, memilih display target secara cerdas, dan menghitung geometri terpusat
@MainActor
public final class ScreenDetector: ObservableObject {
    @Published public private(set) var currentMetrics: IslandLayoutMetrics
    
    private var screenChangeCancellable: AnyCancellable?
    
    public init() {
        self.currentMetrics = ScreenDetector.computeMetrics()
        setupScreenChangeObserver()
    }
    
    /// Menghitung metrik tata letak dari layar target
    public static func computeMetrics() -> IslandLayoutMetrics {
        let screens = NSScreen.screens
        guard let targetScreen = DisplayContext.selectTargetScreen(from: screens) else {
            AppLogger.display.warning("No display detected, using fallback metrics.")
            return .fallback
        }
        
        let context = DisplayContext.from(screen: targetScreen)
        
        let calculatedWidth = context.screenFrame.width - context.auxiliaryTopLeftWidth - context.auxiliaryTopRightWidth
        
        AppLogger.display.info("Selected screen frame: \(context.screenFrame.debugDescription), hasNotch: \(context.hasHardwareNotch)")
        
        return IslandLayoutMetrics(
            screenFrame: context.screenFrame,
            hasHardwareNotch: context.hasHardwareNotch,
            rawNotchWidth: calculatedWidth,
            safeAreaTop: context.safeAreaTop
        )
    }
    
    public func refresh() {
        let newMetrics = ScreenDetector.computeMetrics()
        if self.currentMetrics != newMetrics {
            self.currentMetrics = newMetrics
            AppLogger.display.info("Display metrics updated: notchWidth=\(newMetrics.notchWidth), height=\(newMetrics.notchHeight)")
        }
    }
    
    private func setupScreenChangeObserver() {
        screenChangeCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                AppLogger.display.info("Screen parameters changed notification received.")
                self?.refresh()
            }
    }
}
