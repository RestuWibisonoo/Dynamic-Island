import AppKit
import SwiftUI

/// NSPanel kustom tanpa border, mengambang di atas semua aplikasi & Space tanpa mencuri fokus (non-activating)
public final class IslandPanel: NSPanel {
    public weak var viewModel: IslandViewModel?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        self.level = .statusBar + 1
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.becomesKeyOnlyIfNeeded = false
        self.acceptsMouseMovedEvents = false
        self.ignoresMouseEvents = true
        
        setupKeyMonitors()
    }
    
    deinit {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupKeyMonitors() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    if let vm = self?.viewModel, vm.state.isExpanded {
                        vm.dismissLock()
                    }
                }
            }
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                if let vm = self?.viewModel, vm.state.isExpanded {
                    vm.dismissLock()
                    return nil
                }
            }
            return event
        }
    }
    
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
