import AppKit
import SwiftUI
import Combine

/// Mendeteksi geometri layar dan ukuran notch fisik MacBook (atau mode Floating Pill jika tanpa notch)
@MainActor
public final class ScreenDetector: ObservableObject {
    @Published public private(set) var hasHardwareNotch: Bool = false
    @Published public private(set) var notchWidth: CGFloat = 180
    @Published public private(set) var notchHeight: CGFloat = 32.0
    @Published public private(set) var screenFrame: NSRect = .zero
    @Published public private(set) var notchFrame: NSRect = .zero
    
    // Dimensi sayap (ears) di kiri dan kanan notch kamera
    public let earWidth: CGFloat = 76
    
    // Mengikuti standar mikro-offset (+1.0pt):
    // Ditambahkan hanya 1.0pt ke bawah agar membungkus micro-curve tompel fisik MacBook
    // secara sempurna tanpa menyentuh tab aplikasi fullscreen di bawahnya.
    public let physicalNotchExtraHeight: CGFloat = 1.0
    public let physicalNotchExtraWidth: CGFloat = 2.0
    
    private var screenChangeObserver: AnyCancellable?
    
    public init() {
        updateScreenMetrics()
        setupScreenChangeObserver()
    }
    
    public func updateScreenMetrics() {
        guard let screen = NSScreen.main else { return }
        self.screenFrame = screen.frame
        
        let topInset = screen.safeAreaInsets.top
        
        if topInset > 0, let leftArea = screen.auxiliaryTopLeftArea, let rightArea = screen.auxiliaryTopRightArea {
            // Perangkat memiliki hardware notch fisik
            self.hasHardwareNotch = true
            let calculatedWidth = screen.frame.width - leftArea.width - rightArea.width
            self.notchWidth = max(calculatedWidth + physicalNotchExtraWidth, 180)
            // Pas 32.0pt: Sejajar presisi 1:1 dengan garis menu bar Apple
            self.notchHeight = topInset + physicalNotchExtraHeight
            
            let notchX = screen.frame.origin.x + leftArea.width - (physicalNotchExtraWidth / 2)
            let notchY = screen.frame.origin.y + screen.frame.height - notchHeight
            self.notchFrame = NSRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
        } else {
            // Layar tanpa notch fisik (Monitor eksternal, iMac, Mac Mini, MacBook lama)
            self.hasHardwareNotch = false
            self.notchWidth = 180
            self.notchHeight = 32
            
            let pillX = screen.frame.origin.x + (screen.frame.width - notchWidth) / 2
            let pillY = screen.frame.origin.y + screen.frame.height - notchHeight - 6
            self.notchFrame = NSRect(x: pillX, y: pillY, width: notchWidth, height: notchHeight)
        }
    }
    
    /// Total lebar compact mode:
    /// Pada notch fisik = lebar notch + sayap kiri + sayap kanan
    public var compactTotalWidth: CGFloat {
        if hasHardwareNotch {
            return notchWidth + (earWidth * 2)
        } else {
            return notchWidth
        }
    }
    
    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateScreenMetrics()
            }
    }
}
