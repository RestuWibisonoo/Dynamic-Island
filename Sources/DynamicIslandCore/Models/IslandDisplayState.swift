import Foundation

/// Status tampilan dan ekspansi Dynamic Island
public enum ExpandReason: String, Sendable, Equatable {
    case hover
    case locked
}

public enum IslandDisplayState: Equatable, Sendable {
    case compact
    case expanded(reason: ExpandReason)
    case temporaryHUD(title: String, icon: String, value: Double)
    
    public var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }
    
    public var isLocked: Bool {
        if case .expanded(let reason) = self {
            return reason == .locked
        }
        return false
    }
}
