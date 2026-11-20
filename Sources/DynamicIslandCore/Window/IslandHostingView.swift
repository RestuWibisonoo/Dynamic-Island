import AppKit
import SwiftUI

/// NSHostingView khusus dengan sistem pelacakan kursor dua-arah (Channel B):
/// - Memiliki NSTrackingArea yang mencakup SELURUH frame fixed hosting view (520x260),
///   bukan hanya bentuk pulau.
/// - Menghasilkan event `mouseMoved`, `mouseEntered`, dan `mouseExited` secara konsisten
///   bahkan ketika pointer berada di strip transparan fixed NSPanel di luar bentuk pulau visual.
/// - Membatasi pengujian interaksi klik (`hitTest`) HANYA pada geometri fisik pulau yang sedang aktif,
///   sehingga seluruh piksel transparan di luar bentuk pulau mengembalikan `nil`.
public final class IslandHostingView: NSHostingView<AnyView> {
    public var islandContentRect: (() -> CGRect)?
    public var onMouseEvent: ((NSPoint, String) -> Void)?
    
    private var trackingArea: NSTrackingArea?
    
    /// Properti publik untuk verifikasi pengujian unit test bahwa opsi tracking area terkonfigurasi dengan benar
    public var activeTrackingArea: NSTrackingArea? { trackingArea }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        // Channel B: Tracking area mencakup SELURUH bounds panel fixed-size.
        // Opsi WAJIB:
        // - .mouseMoved: Menerima pergerakan kursor di seluruh area panel
        // - .mouseEnteredAndExited: Menerima transisi masuk dan keluar batas panel
        // - .activeAlways: Berfungsi aktif bahkan saat aplikasi aksesoris tidak menjadi key window
        // - .inVisibleRect: Menjamin area tracking mencakup seluruh area pandang view yang valid
        // - .enabledDuringMouseDrag: Mempertahankan tracking saat proses drag berlangsung
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect,
            .enabledDuringMouseDrag
        ]
        
        let newArea = NSTrackingArea(
            rect: .zero,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        self.trackingArea = newArea
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouseEvent?(NSEvent.mouseLocation, "TrackingArea_Move")
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouseEvent?(NSEvent.mouseLocation, "TrackingArea_Enter")
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseEvent?(NSEvent.mouseLocation, "TrackingArea_Exit")
    }
    
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
