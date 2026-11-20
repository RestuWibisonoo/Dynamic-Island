import AppKit
import SwiftUI
import Combine

/// Pengendali jendela NSPanel yang mengelola penempatan, ukuran dinamis, dan pelacakan interaksi kursor
@MainActor
public final class IslandWindowController {
    public let panel: IslandPanel
    public let hostingView: IslandHostingView
    private let viewModel: IslandViewModel
    private let screenDetector: ScreenDetector
    
    private var cancellables = Set<AnyCancellable>()
    private var pendingShrinkWorkItem: DispatchWorkItem?
    
    private nonisolated(unsafe) var globalMouseMonitor: Any?
    private nonisolated(unsafe) var localMouseMonitor: Any?
    
    private var isMouseInside: Bool = false
    private var isDismissedUntilExit: Bool = false
    
    public init(viewModel: IslandViewModel, screenDetector: ScreenDetector) {
        self.viewModel = viewModel
        self.screenDetector = screenDetector
        
        let initialMetrics = screenDetector.currentMetrics
        // Arsitektur Jendela Tetap (Fixed-Size NSPanel Architecture):
        // Panel selalu berukuran tetap (maksimum dimensi ekspansi + margin) dan di-anchor ke tepi atas layar.
        // Dengan demikian panel tidak pernah di-resize saat runtime, origin Cocoa tidak melompat,
        // dan Dynamic Island tidak pernah terlepas dari notch fisik saat ekspansi/penyusutan.
        let fixedFrame = initialMetrics.fixedPanelFrame
        
        let panel = IslandPanel(contentRect: fixedFrame)
        panel.viewModel = viewModel
        
        let rootView = IslandRootView(viewModel: viewModel)
        let hosting = IslandHostingView(rootView: AnyView(rootView))
        hosting.frame = NSRect(origin: .zero, size: fixedFrame.size)
        
        // Konfigurasikan batas hit-testing dinamis agar piksel transparan tembus ke aplikasi di bawahnya
        hosting.islandContentRect = { [weak hosting, weak viewModel, weak screenDetector] in
            guard let hosting = hosting, let vm = viewModel, let detector = screenDetector else {
                return .zero
            }
            let bounds = hosting.bounds
            let isNotch = detector.currentMetrics.hasHardwareNotch
            let topOffset: CGFloat = isNotch ? 0 : 6
            let w = vm.currentWidth
            let h = vm.currentHeight
            let x = (bounds.width - w) / 2
            return CGRect(x: x, y: topOffset, width: w, height: h)
        }
        
        panel.contentView = hosting
        panel.orderFrontRegardless()
        
        self.panel = panel
        self.hostingView = hosting
        
        setupBindings()
        setupMouseTracking()
    }
    
    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupBindings() {
        // Sinkronisasi perubahan geometri layar
        screenDetector.$currentMetrics
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                self?.repositionPanel(metrics: metrics)
            }
            .store(in: &cancellables)
        
        // Respons ketika Mac bangun dari tidur (wake from sleep)
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.screenDetector.refresh()
                self.repositionPanel(metrics: self.screenDetector.currentMetrics)
            }
            .store(in: &cancellables)
        
        // Sinkronisasi perubahan status (compact vs expanded):
        // Pada Arsitektur Fixed-Size NSPanel, jendela fisik TIDAK PERNAH di-resize saat runtime.
        // Hanya konten SwiftUI di dalamnya yang menganimasikan lebar dan tingginya secara mulus.
        viewModel.onResizeRequest = { [weak self] state, isImmediate in
            self?.handleStateResize(state: state, isImmediate: isImmediate)
        }
        
        // Reset hover state jika user menutup paksa via Escape
        viewModel.onDismissLock = { [weak self] in
            guard let self = self else { return }
            self.isDismissedUntilExit = true
            self.panel.ignoresMouseEvents = true
        }
    }
    
    private func setupMouseTracking() {
        // Pelacakan mouse global (saat aplikasi lain seperti browser/YouTube sedang aktif di depan)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseLocation(NSEvent.mouseLocation)
            }
        }
        
        // Pelacakan mouse lokal (saat panel atau menu bar sedang menerima event)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseLocation(NSEvent.mouseLocation)
            return event
        }
    }
    
    private func handleMouseLocation(_ location: NSPoint) {
        guard panel.isVisible else { return }
        
        let metrics = screenDetector.currentMetrics
        
        // 1. Hitung frame visual fisik dari pulau yang tampak saat ini (tight visible rect)
        let visibleRect = metrics.visibleIslandRect(width: viewModel.currentWidth, height: viewModel.currentHeight)
        let isOverVisibleIsland = visibleRect.contains(location)
        
        // 2. Hitung zona deteksi hover dengan deadband histeresis (untuk pemicuan ekspansi yang stabil)
        let hoverRect = metrics.hoverDetectionRect(for: viewModel.state)
        let isInsideHover = hoverRect.contains(location)
        
        // Jika island baru saja di-dismiss (misal tombol Esc), jangan buka lagi sampai kursor benar-benar keluar
        if isDismissedUntilExit {
            if !isInsideHover && !isOverVisibleIsland {
                isDismissedUntilExit = false
                isMouseInside = false
            }
            if !panel.ignoresMouseEvents {
                panel.ignoresMouseEvents = true
            }
            return
        }
        
        // 3. Dynamic Mouse Event Routing via ignoresMouseEvents:
        // HANYA ketika pointer berada tepat di atas batas fisik pulau yang tampak,
        // aktifkan interaksi (ignoresMouseEvents = false) agar user dapat mengklik tombol kontrol (Play, Pause, Pin, Slider).
        // Begitu pointer bergerak ke luar batas fisik pulau (menuju area video fullscreen atau toolbar Chrome),
        // setel ignoresMouseEvents = true SEKETIKA tanpa delay!
        // Ini memastikan macOS Window Server meneruskan 100% event pergerakan kursor ke aplikasi
        // fullscreen di bawahnya (Chrome/Safari/YouTube) sehingga kontrol navigasi & tombol traffic light
        // dapat melakukan auto-hide secara mulus tanpa terhalang sama sekali.
        let targetIgnores = !isOverVisibleIsland
        if panel.ignoresMouseEvents != targetIgnores {
            panel.ignoresMouseEvents = targetIgnores
            AppLogger.window.debug("panel.ignoresMouseEvents updated to \(targetIgnores)")
        }
        
        // 4. Filter redundan untuk pemicu State Machine ViewModel
        guard isInsideHover != isMouseInside else { return }
        isMouseInside = isInsideHover
        
        AppLogger.hover.debug("Hover boundary crossed: inside=\(isInsideHover), point=(\(location.x), \(location.y)), state=\(String(describing: self.viewModel.state))")
        
        viewModel.onHoverChanged(isInsideHover)
    }
    
    private func repositionPanel(metrics: IslandLayoutMetrics) {
        // Hanya dipanggil saat konfigurasi monitor berubah atau sistem bangun dari tidur
        let frame = metrics.fixedPanelFrame
        if panel.frame != frame {
            AppLogger.window.info("Repositioning fixed panel frame to \(frame.debugDescription)")
            panel.setFrame(frame, display: true, animate: false)
            hostingView.frame = NSRect(origin: .zero, size: frame.size)
        }
    }
    
    private func handleStateResize(state: IslandDisplayState, isImmediate: Bool) {
        // Pada Arsitektur Fixed-Size NSPanel (seperti sayweer/dynamicIsland):
        // panel.setFrame TIDAK PERNAH dipanggil saat hover expand atau collapse!
        // Ukuran jendela fisik tetap konstan, sementara konten SwiftUI di dalamnya mengalir ke bawah.
        // Ini menjamin kestabilan posisi jangkar atas (zero detachment) dan menghindari gangguan auto-hide Window Server.
    }
}
