import SwiftUI
import Combine

/// Model dan Mesin Status (*State Machine*) untuk interaksi, hover timing, dan penyajian Dynamic Island
@MainActor
public final class IslandViewModel: ObservableObject {
    @Published public private(set) var state: IslandDisplayState = .compact
    @Published public private(set) var isHovered: Bool = false
    
    // Nilai dimensi dinamis yang disinkronkan dengan state
    @Published public var currentWidth: CGFloat = 180
    @Published public var currentHeight: CGFloat = 32.0
    
    // Penyedia Data (Dependency Injection)
    public let mediaProvider: any MediaProviding
    public let batteryProvider: any BatteryProviding
    public let systemProvider: any SystemMonitorProviding
    public let screenDetector: ScreenDetector
    
    // Callback ke Window Controller untuk penyesuaian jendela
    public var onResizeRequest: ((IslandDisplayState, Bool) -> Void)?
    public var onDismissLock: (() -> Void)?
    
    private var hoverEnterWorkItem: DispatchWorkItem?
    private var hoverExitWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        screenDetector: ScreenDetector,
        mediaProvider: (any MediaProviding)? = nil,
        batteryProvider: (any BatteryProviding)? = nil,
        systemProvider: (any SystemMonitorProviding)? = nil
    ) {
        self.screenDetector = screenDetector
        self.mediaProvider = mediaProvider ?? MockMediaProvider()
        self.batteryProvider = batteryProvider ?? MockBatteryProvider()
        self.systemProvider = systemProvider ?? MockSystemMonitorProvider()
        
        let initialMetrics = screenDetector.currentMetrics
        self.currentWidth = initialMetrics.compactWidth
        self.currentHeight = initialMetrics.compactHeight
        
        setupScreenMetricsBinding()
    }
    
    private func setupScreenMetricsBinding() {
        screenDetector.$currentMetrics
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                guard let self = self else { return }
                if !self.state.isExpanded {
                    self.currentWidth = metrics.compactWidth
                    self.currentHeight = metrics.compactHeight
                } else {
                    self.currentWidth = metrics.expandedWidth
                    self.currentHeight = metrics.expandedHeight
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Machine Transitions
    
    public func onHoverChanged(_ hovering: Bool) {
        AppLogger.hover.debug("onHoverChanged called: hovering=\(hovering), currentState=\(String(describing: self.state))")
        
        if state.isLocked {
            isHovered = hovering
            return
        }
        
        if hovering {
            // Batalkan jadwal penutupan yang sedang berjalan (pointer re-entry)
            hoverExitWorkItem?.cancel()
            hoverExitWorkItem = nil
            
            isHovered = true
            
            // Jika sudah expanded, jangan picu ekspansi ulang atau restart animasi
            if state.isExpanded {
                return
            }
            
            // Batalkan debounce enter sebelumnya jika ada
            hoverEnterWorkItem?.cancel()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Pastikan kursor masih berada di dalam sebelum melakukan ekspansi
                guard self.isHovered && !self.state.isExpanded else { return }
                self.transitionTo(state: .expanded(reason: .hover))
            }
            hoverEnterWorkItem = item
            DispatchQueue.main.asyncAfter(
                deadline: .now() + DesignTokens.AnimationDuration.hoverEnterDebounce,
                execute: item
            )
        } else {
            // Batalkan jadwal pembukaan yang belum sempat dieksekusi
            hoverEnterWorkItem?.cancel()
            hoverEnterWorkItem = nil
            
            isHovered = false
            
            // Jika sudah compact, tidak ada yang perlu ditutup
            if !state.isExpanded {
                return
            }
            
            // Jika island terkunci buka, kursor keluar tidak boleh menutup island
            if state.isLocked {
                return
            }
            
            hoverExitWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Validasi ulang: jangan tutup jika terkunci atau kursor sudah masuk kembali
                guard !self.state.isLocked && !self.isHovered else { return }
                self.transitionTo(state: .compact)
            }
            hoverExitWorkItem = item
            DispatchQueue.main.asyncAfter(
                deadline: .now() + DesignTokens.AnimationDuration.hoverExitDelay,
                execute: item
            )
        }
    }
    
    public func toggleLockOpen() {
        if state.isLocked {
            transitionTo(state: .compact)
        } else {
            transitionTo(state: .expanded(reason: .locked))
        }
    }
    
    public func dismissLock() {
        onDismissLock?()
        transitionTo(state: .compact)
    }
    
    public func transitionTo(state: IslandDisplayState) {
        // Abaikan jika transisi menuju state yang sama persis
        if self.state == state {
            return
        }
        
        // Batalkan semua work item pending agar transisi lama tidak menimpa state baru
        hoverEnterWorkItem?.cancel()
        hoverEnterWorkItem = nil
        hoverExitWorkItem?.cancel()
        hoverExitWorkItem = nil
        
        // Jika berpindah antara dua status expanded (misal: dari hover ke locked)
        if self.state.isExpanded && state.isExpanded {
            self.state = state
            AppLogger.state.info("State updated within expanded mode: \(String(describing: state))")
            return
        }
        
        AppLogger.state.info("Transitioning state: \(String(describing: self.state)) -> \(String(describing: state))")
        
        let metrics = screenDetector.currentMetrics
        let targetWidth = state.isExpanded ? metrics.expandedWidth : metrics.compactWidth
        let targetHeight = state.isExpanded ? metrics.expandedHeight : metrics.compactHeight
        
        if state.isExpanded {
            // Minta window controller melebarkan jendela fisik seketika
            onResizeRequest?(state, true)
            
            withAnimation(.interactiveSpring(
                response: DesignTokens.AnimationDuration.springResponse,
                dampingFraction: DesignTokens.AnimationDuration.springDamping,
                blendDuration: 0
            )) {
                self.state = state
                self.isHovered = true
                self.currentWidth = targetWidth
                self.currentHeight = targetHeight
            }
        } else {
            withAnimation(.interactiveSpring(
                response: DesignTokens.AnimationDuration.springResponse,
                dampingFraction: DesignTokens.AnimationDuration.springDamping,
                blendDuration: 0
            )) {
                self.state = .compact
                self.isHovered = false
                self.currentWidth = targetWidth
                self.currentHeight = targetHeight
            }
            
            // Beri tahu window controller untuk mengecilkan jendela setelah animasi spring selesai
            onResizeRequest?(.compact, false)
        }
    }
}
