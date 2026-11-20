import AppKit
import SwiftUI
import Combine

/// Pengendali jendela NSPanel yang mengelola penempatan, ukuran dinamis, dan pelacakan interaksi kursor.
/// Menggunakan arsitektur Active Mouse-Position Watchdog (Part A) untuk determinisme 100% pada auto-hide fullscreen.
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
    
    // ==========================================
    // WATCHDOG STATE (PART A.2 & A.3)
    // ==========================================
    private var watchdogTimer: Timer?
    public private(set) var isWatchdogRunning: Bool = false
    public var watchdogPollingInterval: TimeInterval = 1.0 / 50.0 // ~50 Hz
    
    private var isDragging: Bool = false
    private var isMouseInside: Bool = false
    private var isDismissedUntilExit: Bool = false
    
    public var isCurrentlyDragging: Bool {
        get { isDragging }
        set { isDragging = newValue }
    }
    
    #if DEBUG
    public var isDiagnosticFallbackEnabled: Bool = false
    public private(set) var diagnosticLastExitTimestamp: Date?
    #endif
    
    public init(viewModel: IslandViewModel, screenDetector: ScreenDetector) {
        self.viewModel = viewModel
        self.screenDetector = screenDetector
        
        let initialMetrics = screenDetector.currentMetrics
        // Arsitektur Jendela Tetap (Fixed-Size NSPanel Architecture):
        // Panel selalu berukuran tetap (maksimum dimensi ekspansi + margin) dan di-anchor ke tepi atas layar.
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
        MainActor.assumeIsolated {
            stopWatchdog()
        }
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
        
        viewModel.onResizeRequest = { [weak self] state, isImmediate in
            self?.handleStateResize(state: state, isImmediate: isImmediate)
        }
        
        // Reset hover state jika user menutup paksa via Escape
        viewModel.onDismissLock = { [weak self] in
            guard let self = self else { return }
            self.isDismissedUntilExit = true
            self.setPanelInteractive(false, reason: "DISMISS_LOCK")
        }
    }
    
    private func setupMouseTracking() {
        // Global Monitor: Mendeteksi masuknya kursor saat panel berada dalam status click-through (ignoresMouseEvents == true)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.panel.isVisible else { return }
                
                let loc = NSEvent.mouseLocation
                let metrics = self.screenDetector.currentMetrics
                let visibleRect = metrics.visibleIslandRect(width: self.viewModel.currentWidth, height: self.viewModel.currentHeight)
                
                if visibleRect.contains(loc) {
                    if self.isDismissedUntilExit { return }
                    
                    self.setPanelInteractive(true, reason: "GLOBAL_ENTER")
                    
                    let hoverRect = metrics.hoverDetectionRect(for: self.viewModel.state)
                    if hoverRect.contains(loc) && !self.isMouseInside {
                        self.isMouseInside = true
                        self.viewModel.onHoverChanged(true)
                    }
                } else {
                    if self.isDismissedUntilExit {
                        let hoverRect = metrics.hoverDetectionRect(for: self.viewModel.state)
                        if !hoverRect.contains(loc) {
                            self.isDismissedUntilExit = false
                            self.isMouseInside = false
                        }
                    }
                }
            }
        }
        
        // Local Monitor: Menangani interaksi drag kursor (scrubber volume/seek)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return event }
            
            switch event.type {
            case .leftMouseDown:
                let loc = NSEvent.mouseLocation
                let visibleRect = self.screenDetector.currentMetrics.visibleIslandRect(width: self.viewModel.currentWidth, height: self.viewModel.currentHeight)
                if visibleRect.contains(loc) {
                    self.isDragging = true
                    AppLogger.window.info("[LocalMonitor] LeftMouseDown inside visibleRect -> isDragging = true")
                }
            case .leftMouseDragged:
                // Pertahankan interaktivitas selama drag aktif
                break
            case .leftMouseUp:
                self.isDragging = false
                AppLogger.window.info("[LocalMonitor] LeftMouseUp -> isDragging = false")
                
                // Evaluasi ulang posisi kursor seketika setelah mouse-up
                let loc = NSEvent.mouseLocation
                let visibleRect = self.screenDetector.currentMetrics.visibleIslandRect(width: self.viewModel.currentWidth, height: self.viewModel.currentHeight)
                if !visibleRect.contains(loc) {
                    self.setPanelInteractive(false, reason: "MOUSE_UP_OUTSIDE")
                    if self.isMouseInside {
                        self.isMouseInside = false
                        self.viewModel.onHoverChanged(false)
                    }
                }
            default:
                break
            }
            return event
        }
    }
    
    // ==========================================
    // AUTHORITATIVE INTERACTIVITY CONTROLLER (PART A.3)
    // ==========================================
    
    /// Pengendali otoritatif tunggal untuk mengatur apakah panel menangkap mouse event atau click-through
    public func setPanelInteractive(_ enabled: Bool, at location: NSPoint? = nil, reason: String) {
        let loc = location ?? NSEvent.mouseLocation
        let metrics = screenDetector.currentMetrics
        let visibleRect = metrics.visibleIslandRect(width: viewModel.currentWidth, height: viewModel.currentHeight)
        let previousIgnores = panel.ignoresMouseEvents
        
        if enabled {
            // Konfirmasi kursor benar-benar berada di dalam bentuk pulau visual aktual
            guard visibleRect.contains(loc) else { return }
            
            let targetIgnores = false
            if panel.ignoresMouseEvents != targetIgnores {
                panel.ignoresMouseEvents = targetIgnores
                logStateTransition(reason: reason, loc: loc, visibleRect: visibleRect, previousIgnores: previousIgnores, targetIgnores: targetIgnores)
            }
            
            startWatchdog()
        } else {
            // Disabled: SEKETIKA set click-through agar aplikasi di bawahnya (browser/video) langsung menerima input path
            let targetIgnores = true
            if panel.ignoresMouseEvents != targetIgnores {
                panel.ignoresMouseEvents = targetIgnores
                logStateTransition(reason: reason, loc: loc, visibleRect: visibleRect, previousIgnores: previousIgnores, targetIgnores: targetIgnores)
            }
            
            stopWatchdog()
            
            #if DEBUG
            if isDiagnosticFallbackEnabled {
                runDiagnosticFallbackTest()
            }
            #endif
        }
    }
    
    public func setPanelInteractive(_ enabled: Bool, reason: String) {
        setPanelInteractive(enabled, at: nil, reason: reason)
    }
    
    // ==========================================
    // ACTIVE WATCHDOG ENGINE (PART A.2)
    // ==========================================
    
    public func startWatchdog() {
        guard watchdogTimer == nil else { return } // Menjamin tidak ada timer duplikat
        isWatchdogRunning = true
        AppLogger.window.info("[Watchdog] WATCHDOG_STARTED (poll: ~50Hz, mode: common)")
        
        let timer = Timer(timeInterval: watchdogPollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.watchdogTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.watchdogTimer = timer
    }
    
    public func stopWatchdog() {
        guard watchdogTimer != nil else { return }
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        isWatchdogRunning = false
        AppLogger.window.info("[Watchdog] WATCHDOG_STOPPED")
    }
    
    @MainActor
    public func watchdogTick() {
        guard panel.isVisible else { return }
        let loc = NSEvent.mouseLocation
        
        // Rekalkulasi dinamis bentuk pulau aktual (menyesuaikan saat animasi ukuran berlangsung)
        let metrics = screenDetector.currentMetrics
        let visibleRect = metrics.visibleIslandRect(width: viewModel.currentWidth, height: viewModel.currentHeight)
        let isInsideVisible = visibleRect.contains(loc)
        
        // Selama user aktif melakukan drag pada kontrol (slider), lindungi interaksi
        if isDragging {
            return
        }
        
        if !isInsideVisible {
            // 1. SEKETIKA nonaktifkan interaktivitas panel SEBELUM memicu collapse atau transisi lainnya!
            setPanelInteractive(false, reason: "WATCHDOG_POINTER_OUTSIDE_VISIBLE_RECT")
            
            // 2. Perbarui status hover secara terpisah tanpa menunda rilis event input
            if isMouseInside {
                isMouseInside = false
                AppLogger.hover.debug("[Watchdog] Hover boundary exited: inside=false, point=(\(loc.x), \(loc.y)), state=\(String(describing: self.viewModel.state))")
                viewModel.onHoverChanged(false)
            }
        } else {
            // Kursor di dalam pulau visual: perbarui histeresis hover
            let hoverRect = metrics.hoverDetectionRect(for: viewModel.state)
            let isInsideHover = hoverRect.contains(loc)
            
            if isInsideHover != isMouseInside {
                isMouseInside = isInsideHover
                AppLogger.hover.debug("[Watchdog] Hover boundary updated: inside=\(isInsideHover), point=(\(loc.x), \(loc.y)), state=\(String(describing: self.viewModel.state))")
                viewModel.onHoverChanged(isInsideHover)
            }
        }
    }
    
    /// Metode pembantu untuk routing mouse (kompatibilitas pengujian)
    public func updateMouseRouting(location: NSPoint, source: String) {
        let metrics = screenDetector.currentMetrics
        let visibleRect = metrics.visibleIslandRect(width: viewModel.currentWidth, height: viewModel.currentHeight)
        
        if visibleRect.contains(location) {
            setPanelInteractive(true, at: location, reason: source)
        } else {
            if !isDragging {
                setPanelInteractive(false, at: location, reason: source)
            }
        }
    }
    
    private func logStateTransition(reason: String, loc: NSPoint, visibleRect: CGRect, previousIgnores: Bool, targetIgnores: Bool) {
        let metrics = screenDetector.currentMetrics
        AppLogger.window.info("[\(reason)] PANEL_INTERACTIVE=\(!targetIgnores) | ignoresMouseEvents: \(previousIgnores) -> \(targetIgnores) | loc: (\(Int(loc.x)), \(Int(loc.y))) | visibleRect: \(visibleRect.debugDescription) | fixedFrame: \(metrics.fixedPanelFrame.debugDescription) | level: \(self.panel.level.rawValue) | state: \(String(describing: self.viewModel.state)) | watchdog: \(self.isWatchdogRunning) | isDragging: \(self.isDragging)")
    }
    
    #if DEBUG
    private func runDiagnosticFallbackTest() {
        diagnosticLastExitTimestamp = Date()
        let wasVisible = panel.isVisible
        AppLogger.window.info("[DiagnosticFallback] Pointer exited visible island. Timestamp: \(Date()), wasVisible: \(wasVisible). Performing temporary orderOut test...")
        panel.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.panel.orderFrontRegardless()
            AppLogger.window.info("[DiagnosticFallback] Temporary orderOut test completed, restored orderFrontRegardless.")
        }
    }
    #endif
    
    private func repositionPanel(metrics: IslandLayoutMetrics) {
        let frame = metrics.fixedPanelFrame
        if panel.frame != frame {
            AppLogger.window.info("Repositioning fixed panel frame to \(frame.debugDescription)")
            panel.setFrame(frame, display: true, animate: false)
            hostingView.frame = NSRect(origin: .zero, size: frame.size)
        }
    }
    
    private func handleStateResize(state: IslandDisplayState, isImmediate: Bool) {
        // Pada Arsitektur Fixed-Size NSPanel: frame fisik jendela tidak pernah di-resize saat hover!
    }
}
