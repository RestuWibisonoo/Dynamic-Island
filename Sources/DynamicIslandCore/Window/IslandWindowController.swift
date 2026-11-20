import AppKit
import SwiftUI
import Combine

/// Pengendali jendela NSPanel yang mengelola penempatan, ukuran dinamis, dan sinkronisasi tampilan
@MainActor
public final class IslandWindowController {
    public let panel: IslandPanel
    public let hostingView: NSHostingView<AnyView>
    private let viewModel: IslandViewModel
    private let screenDetector: ScreenDetector
    
    private var cancellables = Set<AnyCancellable>()
    private var pendingShrinkWorkItem: DispatchWorkItem?
    
    public init(viewModel: IslandViewModel, screenDetector: ScreenDetector) {
        self.viewModel = viewModel
        self.screenDetector = screenDetector
        
        let initialMetrics = screenDetector.currentMetrics
        let initialFrame = initialMetrics.panelFrame(for: .compact)
        
        let panel = IslandPanel(contentRect: initialFrame)
        panel.viewModel = viewModel
        
        let rootView = IslandRootView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: AnyView(rootView))
        hosting.frame = NSRect(origin: .zero, size: initialFrame.size)
        
        panel.contentView = hosting
        panel.orderFrontRegardless()
        
        self.panel = panel
        self.hostingView = hosting
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Sinkronisasi perubahan geometri layar
        screenDetector.$currentMetrics
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                self?.repositionPanel(metrics: metrics)
            }
            .store(in: &cancellables)
        
        // Sinkronisasi perubahan status (compact vs expanded)
        viewModel.onResizeRequest = { [weak self] state, isImmediate in
            self?.handleStateResize(state: state, isImmediate: isImmediate)
        }
    }
    
    private func repositionPanel(metrics: IslandLayoutMetrics) {
        let frame = metrics.panelFrame(for: viewModel.state)
        panel.setFrame(frame, display: true, animate: false)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
    }
    
    private func handleStateResize(state: IslandDisplayState, isImmediate: Bool) {
        pendingShrinkWorkItem?.cancel()
        
        let targetFrame = screenDetector.currentMetrics.panelFrame(for: state)
        
        if isImmediate {
            panel.setFrame(targetFrame, display: true, animate: false)
            hostingView.frame = NSRect(origin: .zero, size: targetFrame.size)
        } else {
            // Berikan jeda 0.35s agar animasi SwiftUI spring selesai mengecil sebelum jendela fisik menyusut
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.viewModel.state.isExpanded else { return }
                self.panel.setFrame(targetFrame, display: true, animate: false)
                self.hostingView.frame = NSRect(origin: .zero, size: targetFrame.size)
            }
            self.pendingShrinkWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
        }
    }
}
