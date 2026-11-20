import Foundation
import ServiceManagement
import os.log

/// Mengelola status otomatis aktif saat Mac dinyalakan (Launch at Login) dengan verifikasi status aktual SMAppService
@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public private(set) var isEnabled: Bool = false
    
    private init() {
        refreshStatus()
    }
    
    public func refreshStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            self.isEnabled = (status == .enabled)
            AppLogger.launchAtLogin.debug("LaunchAtLogin status refreshed: \(String(describing: status))")
        }
    }
    
    public func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        AppLogger.launchAtLogin.info("SMAppService registered successfully.")
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        AppLogger.launchAtLogin.info("SMAppService unregistered successfully.")
                    }
                }
            } catch {
                AppLogger.launchAtLogin.error("Failed to update LaunchAtLogin: \(error.localizedDescription)")
            }
            
            // Verifikasi kembali status aktual dari sistem operasi (bukan sekadar asumsi Boolean lokal)
            refreshStatus()
        }
    }
}
