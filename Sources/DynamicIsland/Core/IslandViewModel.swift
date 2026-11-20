import SwiftUI
import Combine

/// Status tampilan Dynamic Island
public enum IslandDisplayState: Equatable {
    case compact      // Istirahat (menempel di notch dengan sayap atau floating pill)
    case expanded     // Diperluas dengan widget lengkap
    case hud(title: String, icon: String, value: Double)
}

/// Model data dan status interaksi Dynamic Island
@MainActor
public final class IslandViewModel: ObservableObject {
    @Published public var state: IslandDisplayState = .compact
    @Published public var isHovered: Bool = false
    @Published public var isLockedOpen: Bool = false
    @Published public var currentWidth: CGFloat = 180
    @Published public var currentHeight: CGFloat = 33.0
    
    // Callback untuk sinkronisasi ukuran fisik jendela NSPanel di AppDelegate
    public var onWindowFrameResizeRequested: ((CGFloat, CGFloat) -> Void)?
    
    // Status Pemutar Musik
    @Published public var isPlayingMedia: Bool = true
    @Published public var currentTrackTitle: String = "Starboy"
    @Published public var currentArtist: String = "The Weeknd"
    @Published public var currentAlbum: String = "Starboy"
    @Published public var trackProgress: Double = 0.38
    @Published public var trackDuration: Double = 230
    @Published public var isScrubbing: Bool = false
    
    // Status Sistem
    @Published public var batteryPercentage: Int = 92
    @Published public var isCharging: Bool = true
    @Published public var volumeLevel: Double = 0.72
    @Published public var cpuUsage: Int = 14
    @Published public var ramUsage: Int = 46
    
    // Drop Shelf Status
    @Published public var isDropTargetActive: Bool = false
    @Published public var droppedFilesCount: Int = 0
    
    private var hoverEnterWorkItem: DispatchWorkItem?
    private var hoverExitWorkItem: DispatchWorkItem?
    private var collapseWindowResizeWorkItem: DispatchWorkItem?
    private var playbackTimer: AnyCancellable?
    public let screenDetector: ScreenDetector
    private var cancellables = Set<AnyCancellable>()
    
    public init(screenDetector: ScreenDetector) {
        self.screenDetector = screenDetector
        self.currentWidth = screenDetector.compactTotalWidth
        self.currentHeight = screenDetector.notchHeight
        
        screenDetector.$notchWidth
            .sink { [weak self] _ in
                guard let self = self, self.state == .compact else { return }
                self.currentWidth = self.screenDetector.compactTotalWidth
                self.currentHeight = self.screenDetector.notchHeight
            }
            .store(in: &cancellables)
            
        startPlaybackSimulationTimer()
    }
    
    private func startPlaybackSimulationTimer() {
        playbackTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlayingMedia, !self.isScrubbing else { return }
                let step = 1.0 / self.trackDuration
                if self.trackProgress + step >= 1.0 {
                    self.trackProgress = 0.0
                } else {
                    self.trackProgress += step
                }
            }
    }
    
    public var currentTimeFormatted: String {
        let currentSeconds = Int(trackProgress * trackDuration)
        let mins = currentSeconds / 60
        let secs = currentSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var remainingTimeFormatted: String {
        let totalSeconds = Int(trackDuration)
        let currentSeconds = Int(trackProgress * trackDuration)
        let remaining = max(totalSeconds - currentSeconds, 0)
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "-%d:%02d", mins, secs)
    }
    
    public func onHoverChanged(_ hovering: Bool) {
        if isLockedOpen && !hovering {
            isHovered = false
            return
        }
        
        if hovering {
            hoverExitWorkItem?.cancel()
            hoverEnterWorkItem?.cancel()
            collapseWindowResizeWorkItem?.cancel()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.expandIsland()
            }
            hoverEnterWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
        } else {
            hoverEnterWorkItem?.cancel()
            hoverExitWorkItem?.cancel()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.collapseIsland()
            }
            hoverExitWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: item)
        }
    }
    
    public func toggleLockOpen() {
        if isLockedOpen {
            isLockedOpen = false
            collapseIsland()
        } else {
            isLockedOpen = true
            expandIsland()
        }
    }
    
    public func dismissLock() {
        isLockedOpen = false
        collapseIsland()
    }
    
    public func expandIsland() {
        collapseWindowResizeWorkItem?.cancel()
        
        // 1. Seketika lebarkan jendela NSPanel agar animasi spring memiliki kanvas penuh
        let targetWidth: CGFloat = 460
        let targetHeight: CGFloat = 220
        onWindowFrameResizeRequested?(targetWidth, targetHeight)
        
        // 2. Animasikan SwiftUI view
        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.78, blendDuration: 0)) {
            self.isHovered = true
            self.state = .expanded
            self.currentWidth = targetWidth
            self.currentHeight = targetHeight
        }
    }
    
    public func collapseIsland() {
        guard !isLockedOpen else { return }
        collapseWindowResizeWorkItem?.cancel()
        
        let compactW = self.screenDetector.compactTotalWidth
        let compactH = self.screenDetector.notchHeight
        
        // 1. Animasikan SwiftUI view mengecil
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.82, blendDuration: 0)) {
            self.isHovered = false
            self.state = .compact
            self.currentWidth = compactW
            self.currentHeight = compactH
        }
        
        // 2. Setelah animasi selesai (0.35 detik), kecilkan jendela NSPanel kembali ke ukuran compact murni!
        // Ini memastikan jendela TIDAK LAGI menutupi atau mengganggu layar video fullscreen di bawahnya!
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .compact else { return }
            self.onWindowFrameResizeRequested?(compactW, compactH)
        }
        collapseWindowResizeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36, execute: item)
    }
    
    public func togglePlayback() {
        isPlayingMedia.toggle()
    }
}
