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
        let initialFrame = initialMetrics.panelFrame(for: .compact)
        
        let panel = IslandPanel(contentRect: initialFrame)
        panel.viewModel = viewModel
        
        let rootView = IslandRootView(viewModel: viewModel)
        let hosting = IslandHostingView(rootView: AnyView(rootView))
        hosting.frame = NSRect(origin: .zero, size: initialFrame.size)
        
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
        
        // Sinkronisasi perubahan status (compact vs expanded)
        viewModel.onResizeRequest = { [weak self] state, isImmediate in
            self?.handleStateResize(state: state, isImmediate: isImmediate)
        }
        
        // Reset hover state jika user menutup paksa via Escape
        viewModel.onDismissLock = { [weak self] in
            self?.isDismissedUntilExit = true
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
        let detectionRect = metrics.hoverDetectionRect(for: viewModel.state)
        let inside = detectionRect.contains(location)
        
        // Jika island baru saja di-dismiss (misal tombol Esc), jangan buka lagi sampai kursor benar-benar keluar
        if isDismissedUntilExit {
            if !inside {
                isDismissedUntilExit = false
                isMouseInside = false
            }
            return
        }
        
        // Filter redudan: hanya proses jika terjadi perubahan batas (masuk atau keluar)
        guard inside != isMouseInside else { return }
        isMouseInside = inside
        
        AppLogger.hover.debug("Hover boundary crossed: inside=\(inside), point=(\(location.x), \(location.y)), state=\(String(describing: self.viewModel.state))")
        
        viewModel.onHoverChanged(inside)
    }
    
    private func repositionPanel(metrics: IslandLayoutMetrics) {
        let frame = metrics.panelFrame(for: viewModel.state)
        if panel.frame != frame {
            AppLogger.window.info("Repositioning panel frame to \(frame.debugDescription)")
            panel.setFrame(frame, display: true, animate: false)
            hostingView.frame = NSRect(origin: .zero, size: frame.size)
        }
    }
    
    private func handleStateResize(state: IslandDisplayState, isImmediate: Bool) {
        pendingShrinkWorkItem?.cancel()
        pendingShrinkWorkItem = nil
        
        let targetFrame = screenDetector.currentMetrics.panelFrame(for: state)
        
        if isImmediate {
            if panel.frame != targetFrame {
                AppLogger.window.debug("Immediate panel resize: \(self.panel.frame.size.debugDescription) -> \(targetFrame.size.debugDescription)")
                panel.setFrame(targetFrame, display: true, animate: false)
                hostingView.frame = NSRect(origin: .zero, size: targetFrame.size)
            }
        } else {
            // Berikan jeda windowShrinkDelay agar animasi SwiftUI spring selesai mengecil sebelum jendela fisik menyusut
            AppLogger.window.debug("Scheduling delayed panel shrink (delay: \(DesignTokens.AnimationDuration.windowShrinkDelay)s)")
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.viewModel.state.isExpanded else {
                    AppLogger.window.debug("Delayed shrink cancelled or invalidated: state is expanded")
                    return
                }
                let compactFrame = self.screenDetector.currentMetrics.panelFrame(for: .compact)
                if self.panel.frame != compactFrame {
                    AppLogger.window.debug("Executing delayed panel shrink: \(compactFrame.size.debugDescription)")
                    self.panel.setFrame(compactFrame, display: true, animate: false)
                    self.hostingView.frame = NSRect(origin: .zero, size: compactFrame.size)
                }
            }
            self.pendingShrinkWorkItem = item
            DispatchQueue.main.asyncAfter(
                deadline: .now() + DesignTokens.AnimationDuration.windowShrinkDelay,
                execute: item
            )
        }
    }
}
