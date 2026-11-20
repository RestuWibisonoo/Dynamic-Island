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
        // Jika sedang terkunci buka (isLocked), pergerakan kursor keluar tidak akan menutup island
        if state.isLocked && !hovering {
            isHovered = false
            return
        }
        
        if hovering {
            hoverExitWorkItem?.cancel()
            hoverEnterWorkItem?.cancel()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.transitionTo(state: .expanded(reason: .hover))
            }
            hoverEnterWorkItem = item
            DispatchQueue.main.asyncAfter(
                deadline: .now() + DesignTokens.AnimationDuration.hoverEnterDebounce,
                execute: item
            )
        } else {
            hoverEnterWorkItem?.cancel()
            hoverExitWorkItem?.cancel()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
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
        transitionTo(state: .compact)
    }
    
    public func transitionTo(state: IslandDisplayState) {
        hoverEnterWorkItem?.cancel()
        hoverExitWorkItem?.cancel()
        
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
