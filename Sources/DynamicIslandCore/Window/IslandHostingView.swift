import AppKit
import SwiftUI

/// NSHostingView khusus yang membatasi pengujian interaksi mouse (hit-testing)
/// HANYA pada geometri fisik pulau yang sedang aktif.
/// Seluruh piksel transparan di luar bentuk pulau akan mengembalikan `nil`,
/// sehingga event klik, drag, hover, dan mouse move langsung tembus (pass-through)
/// ke jendela aplikasi di bawahnya (misal: kontrol navigasi fullscreen video YouTube di browser).
public final class IslandHostingView: NSHostingView<AnyView> {
    public var islandContentRect: (() -> CGRect)?
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let rect = islandContentRect?() else {
            return super.hitTest(point)
        }
        
        // point diterima dalam koordinat superview (unflipped window coordinate space);
        // konversikan ke koordinat lokal view (NSHostingView isFlipped: true)
        let localPoint = convert(point, from: superview)
        
        // Jika titik berada di luar batas bentuk pulau, kembalikan nil agar tembus ke aplikasi di bawahnya
        guard rect.contains(localPoint) else {
            return nil
        }
        
        return super.hitTest(point)
    }
}
