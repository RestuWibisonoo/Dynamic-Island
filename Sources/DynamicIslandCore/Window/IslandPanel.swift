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
        
        // .statusBar(25) + 8 (Layer 33, dari sayweer/dynamicIsland):
        // Mencegah z-order contention dengan menu bar items dan Chrome fullscreen notch auxiliary (Layer 26)
        self.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
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
    
    // canBecomeKey diatur true (seperti sayweer/Atoll) agar kontrol di dalam panel (slider, tombol)
    // dapat menerima interaksi langsung tanpa mengaktifkan aplikasi (karena styleMask .nonactivatingPanel).
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}
