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
        
        // Tetap di level atas status bar
        self.level = .statusBar + 1
        
        // Tampil di semua virtual desktop (Spaces) dan mode fullscreen
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
        
        // PENTING: Jangan biarkan panel mencuri fokus dari pemutar video / browser fullscreen!
        self.becomesKeyOnlyIfNeeded = false
        
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
    
    /// Global & Local monitor untuk menangkap tombol Escape keyboard bahkan saat panel bukan Key Window
    private func setupKeyMonitors() {
        // Monitor global: menangkap tombol Esc saat browser/fullscreen app sedang aktif
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Tombol Escape
                Task { @MainActor in
                    if let vm = self?.viewModel, vm.state == .expanded {
                        vm.dismissLock()
                    }
                }
            }
        }
        
        // Monitor lokal
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Tombol Escape
                if let vm = self?.viewModel, vm.state == .expanded {
                    vm.dismissLock()
                    return nil
                }
            }
            return event
        }
    }
    
    // PENTING: Harus FALSE agar jendela browser (YouTube / Netflix / Chrome)
    // TIDAK PERNAH kehilangan status Key Window saat kursor diarahkan ke Dynamic Island.
    // Dengan begitu, sistem timer auto-hide navigasi fullscreen pada video tidak akan macet/nyangkut!
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
