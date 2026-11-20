import Foundation
import Combine

/// Kontrak protokol untuk monitoring performa sistem (CPU & RAM)
@MainActor
public protocol SystemMonitorProviding: AnyObject {
    var cpuUsage: Int { get }
    var ramUsage: Int { get }
}

/// Implementasi Mock System Monitor Provider
@MainActor
public final class MockSystemMonitorProvider: ObservableObject, SystemMonitorProviding {
    @Published public private(set) var cpuUsage: Int = 14
    @Published public private(set) var ramUsage: Int = 46
    
    public init(cpuUsage: Int = 14, ramUsage: Int = 46) {
        self.cpuUsage = cpuUsage
        self.ramUsage = ramUsage
    }
    
    public func update(cpu: Int, ram: Int) {
        self.cpuUsage = cpu
        self.ramUsage = ram
    }
}
