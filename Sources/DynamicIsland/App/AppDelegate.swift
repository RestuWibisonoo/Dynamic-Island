import AppKit
import SwiftUI

/// Mengatur siklus hidup aplikasi, status bar menu, dan window panel Dynamic Island
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var islandPanel: IslandPanel?
    private var screenDetector = ScreenDetector()
    private lazy var viewModel = IslandViewModel(screenDetector: screenDetector)
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Berjalan sebagai background / accessory app tanpa dock icon yang mengganggu
        NSApp.setActivationPolicy(.accessory)
        
        setupIslandPanel()
        setupStatusBar()
    }
    
    private func setupIslandPanel() {
        // Jendela NSPanel diawali dengan ukuran COMPACT MURNI (hanya pas di notch)
        let initialWidth: CGFloat = screenDetector.compactTotalWidth
        let initialHeight: CGFloat = screenDetector.notchHeight
        
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        
        let panelX = screenRect.origin.x + (screenRect.width - initialWidth) / 2
        let panelY = screenRect.origin.y + screenRect.height - initialHeight
        
        let contentRect = NSRect(x: panelX, y: panelY, width: initialWidth, height: initialHeight)
        let panel = IslandPanel(contentRect: contentRect)
        panel.viewModel = viewModel
        
        let rootView = IslandRootView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight)
        
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.islandPanel = panel
        
        // Hubungkan sinkronisasi ukuran dinamis jendela NSPanel:
        // Saat expanded: jendela membesar seketika agar animasi spring muat
        // Saat collapse: jendela mengecil kembali ke 33pt agar area video fullscreen 100% bebas dari jendela!
        viewModel.onWindowFrameResizeRequested = { [weak self] width, height in
            self?.resizeIslandPanel(width: width, height: height)
        }
    }
    
    private func resizeIslandPanel(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main, let panel = islandPanel else { return }
        let screenRect = screen.frame
        let panelX = screenRect.origin.x + (screenRect.width - width) / 2
        let panelY = screenRect.origin.y + screenRect.height - height
        
        let newFrame = NSRect(x: panelX, y: panelY, width: width, height: height)
        panel.setFrame(newFrame, display: true, animate: false)
        panel.contentView?.frame = NSRect(x: 0, y: 0, width: width, height: height)
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.circle.fill", accessibilityDescription: "Dynamic Island")
        }
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "MacBook Dynamic Island", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let launchAtLoginItem = NSMenuItem(
            title: "Buka Otomatis saat Mac Dinyalakan",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Keluar dari Dynamic Island",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleLaunchAtLogin() {
        let current = LaunchAtLoginManager.shared.isEnabled
        LaunchAtLoginManager.shared.setEnabled(!current)
        setupStatusBar()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
