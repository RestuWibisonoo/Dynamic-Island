import Foundation
import ServiceManagement

/// Mengelola status otomatis aktif saat Mac dinyalakan (Launch at Login)
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public var isEnabled: Bool = false
    
    private init() {
        checkStatus()
    }
    
    public func checkStatus() {
        if #available(macOS 13.0, *) {
            self.isEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    public func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                self.isEnabled = enable
            } catch {
                print("LaunchAtLogin Error: \(error.localizedDescription)")
            }
        }
    }
}
