import AppKit
import SwiftUI
import os.log

/// Mengatur siklus hidup aplikasi, status bar menu, dan window controller Dynamic Island
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    
    private var screenDetector: ScreenDetector!
    private var viewModel: IslandViewModel!
    private var windowController: IslandWindowController!
    
    public override init() {
        super.init()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.lifecycle.info("Application starting up...")
        
        // Mode aplikasi aksesoris background (tanpa icon di Dock)
        NSApp.setActivationPolicy(.accessory)
        
        setupCoreArchitecture()
        setupStatusBar()
    }
    
    private func setupCoreArchitecture() {
        let detector = ScreenDetector()
        self.screenDetector = detector
        
        let vm = IslandViewModel(screenDetector: detector)
        self.viewModel = vm
        
        let controller = IslandWindowController(viewModel: vm, screenDetector: detector)
        self.windowController = controller
        
        AppLogger.lifecycle.info("Core architecture initialized successfully.")
    }
    
    private func setupStatusBar() {
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "circle.circle.fill", accessibilityDescription: "Dynamic Island")
        }
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "MacBook Dynamic Island", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let launchItem = NSMenuItem(
            title: "Buka Otomatis saat Mac Dinyalakan",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(launchItem)
        self.launchAtLoginMenuItem = launchItem
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Keluar dari Dynamic Island",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        item.menu = menu
        self.statusItem = item
    }
    
    @objc private func toggleLaunchAtLogin() {
        let current = LaunchAtLoginManager.shared.isEnabled
        LaunchAtLoginManager.shared.setEnabled(!current)
        
        // Perbarui status menu item di tempat (in-place) tanpa membuat NSStatusItem baru!
        launchAtLoginMenuItem?.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        AppLogger.launchAtLogin.info("LaunchAtLogin toggled to: \(LaunchAtLoginManager.shared.isEnabled)")
    }
    
    @objc private func quitApp() {
        AppLogger.lifecycle.info("Terminating application.")
        NSApplication.shared.terminate(nil)
    }
}
