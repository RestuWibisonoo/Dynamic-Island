import Foundation
import Combine

/// Kontrak protokol untuk status baterai sistem
@MainActor
public protocol BatteryProviding: AnyObject {
    var percentage: Int { get }
    var isCharging: Bool { get }
}

/// Implementasi Mock Battery Provider
@MainActor
public final class MockBatteryProvider: ObservableObject, BatteryProviding {
    @Published public private(set) var percentage: Int = 92
    @Published public private(set) var isCharging: Bool = true
    
    public init(percentage: Int = 92, isCharging: Bool = true) {
        self.percentage = percentage
        self.isCharging = isCharging
    }
    
    public func update(percentage: Int, isCharging: Bool) {
        self.percentage = percentage
        self.isCharging = isCharging
    }
}
