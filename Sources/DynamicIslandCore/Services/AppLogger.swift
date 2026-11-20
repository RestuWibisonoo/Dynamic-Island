import Foundation
import os.log

/// Sistem logging terpadu Apple Unified Logging System (OSLog)
public enum AppLogger {
    private static let subsystem = "com.restuwibisono.DynamicIsland"
    
    public static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
    public static let display = Logger(subsystem: subsystem, category: "Display")
    public static let window = Logger(subsystem: subsystem, category: "Window")
    public static let state = Logger(subsystem: subsystem, category: "State")
    public static let providers = Logger(subsystem: subsystem, category: "Providers")
    public static let launchAtLogin = Logger(subsystem: subsystem, category: "LaunchAtLogin")
}
