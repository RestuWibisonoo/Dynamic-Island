import AppKit
import DynamicIslandCore

@main
@MainActor
struct DynamicIslandApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
